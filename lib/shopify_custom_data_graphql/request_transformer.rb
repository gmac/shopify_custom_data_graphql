# frozen_string_literal: true

require_relative "request_transformer/transformation_map"

module ShopifyCustomDataGraphQL
  class RequestTransformer
    RESERVED_PREFIX = "___"

    GQL_TYPENAME = "__typename"
    HINT_TYPENAME = "#{RESERVED_PREFIX}typehint"
    NAMESPACE_TRANSFORM = "custom_scope"
    STATIC_TYPENAME_TRANSFORM = "static_typename"
    METAOBJECT_TYPENAME_TRANSFORM = "metaobject_typename"

    EXTENSIONS_SCOPE = :extensions
    METAOBJECT_SCOPE = :metaobject
    NATIVE_SCOPE = :native

    def initialize(query, metafield_ns = "custom")
      @query = query
      @schema = query.schema
      @app_context = directive_kwargs(@schema.schema_directives, "app")&.dig(:id)
      @owner_types = @schema.possible_types(@query.get_type("HasMetafields")).to_set
      @root_ext_name = MetafieldTypeResolver.extensions_typename(@schema.query.graphql_name)
      @transform_map = TransformationMap.new(@app_context)
      @metafield_ns = metafield_ns
      @new_fragments = {}
    end

    def perform
      op = @query.selected_operation
      parent_type = @query.root_type_for_operation(op.operation_type)
      op = op.merge(selections: transform_scope(parent_type, op.selections))
      document = GraphQL::Language::Nodes::Document.new(definitions: [op, *@new_fragments.values])
      transforms = @transform_map.as_json
      PreparedQuery.new(
        query: transforms.empty? ? @query.query_string : nil,
        document: transforms.empty? ? @query.document : document,
        transforms: transforms,
      )
    end

    private

    def transform_scope(parent_type, input_selections, scope_type: NATIVE_SCOPE, scope_ns: nil)
      results = input_selections.flat_map do |node|
        case node
        when GraphQL::Language::Nodes::Field
          if node.alias&.start_with?(RESERVED_PREFIX)
            raise ValidationError, "Field aliases starting with `#{RESERVED_PREFIX}` are reserved for system use"
          end

          @transform_map.field_breadcrumb(node) do
            if scope_type == NATIVE_SCOPE && node.name == "extensions" && (parent_type == @schema.query || @owner_types.include?(parent_type))
              @transform_map.apply_field_transform(FieldTransform.new(NAMESPACE_TRANSFORM))
              with_namespace_anchor_field(node) do
                next_type = @query.get_field(parent_type, node.name).type.unwrap
                transform_scope(next_type, node.selections, scope_type: EXTENSIONS_SCOPE, scope_ns: node.alias || node.name)
              end
            elsif scope_type == METAOBJECT_SCOPE && node.name == "system"
              @transform_map.apply_field_transform(FieldTransform.new(NAMESPACE_TRANSFORM))
              with_namespace_anchor_field(node) do
                next_type = @query.get_field(parent_type, node.name).type.unwrap
                transform_scope(next_type, node.selections, scope_ns: node.alias || node.name)
              end
            elsif scope_type == EXTENSIONS_SCOPE && parent_type.graphql_name == @root_ext_name
              build_metaobject_query(parent_type, node, scope_ns: scope_ns)
            elsif scope_type == EXTENSIONS_SCOPE || scope_type == METAOBJECT_SCOPE
              build_metafield(parent_type, node, scope_type: scope_type, scope_ns: scope_ns)
            else
              if scope_ns
                node = node.merge(alias: "#{RESERVED_PREFIX}#{scope_ns}_#{node.alias || node.name}")
              end
              if node.selections&.any?
                next_type = @query.get_field(parent_type, node.name).type.unwrap
                node = node.merge(selections: transform_scope(next_type, node.selections))
              end
              node
            end
          end

        when GraphQL::Language::Nodes::InlineFragment
          fragment_type = node.type.nil? ? parent_type : @query.get_type(node.type.name)
          with_typed_condition(parent_type, fragment_type, scope_type) do
            if MetafieldTypeResolver.extensions_type?(fragment_type.graphql_name)
              transform_scope(fragment_type, node.selections, scope_type: EXTENSIONS_SCOPE, scope_ns: scope_ns)
            elsif MetafieldTypeResolver.metaobject_type?(fragment_type.graphql_name)
              GraphQL::Language::Nodes::InlineFragment.new(
                type: GraphQL::Language::Nodes::TypeName.new(name: "Metaobject"),
                selections: transform_scope(fragment_type, node.selections, scope_type: METAOBJECT_SCOPE, scope_ns: scope_ns),
              )
            else
              GraphQL::Language::Nodes::InlineFragment.new(
                type: GraphQL::Language::Nodes::TypeName.new(name: fragment_type.graphql_name),
                selections: transform_scope(fragment_type, node.selections),
              )
            end
          end

        when GraphQL::Language::Nodes::FragmentSpread
          fragment_def = @query.fragments[node.name]
          fragment_type = @query.get_type(fragment_def.type.name)
          with_typed_condition(parent_type, fragment_type, scope_type) do
            unless @new_fragments[node.name]
              fragment_type_name = fragment_type.graphql_name
              fragment_selections = if MetafieldTypeResolver.extensions_type?(fragment_type.graphql_name)
                fragment_type_name = fragment_type_name.sub(MetafieldTypeResolver::EXTENSIONS_TYPE_SUFFIX, "")
                transform_scope(fragment_type, fragment_def.selections, scope_type: EXTENSIONS_SCOPE, scope_ns: scope_ns)
              elsif MetafieldTypeResolver.metaobject_type?(fragment_type.graphql_name)
                fragment_type_name = "Metaobject"
                transform_scope(fragment_type, fragment_def.selections, scope_type: METAOBJECT_SCOPE, scope_ns: scope_ns)
              else
                transform_scope(fragment_type, fragment_def.selections)
              end

              @new_fragments[node.name] = fragment_def.merge(
                type: GraphQL::Language::Nodes::TypeName.new(name: fragment_type_name),
                selections: fragment_selections,
              )
            end

            node
          end
        end
      end

      compact_typehints(results)
    end

    # custom namespaces prepend an anchor field to hold their position in selection order
    def with_namespace_anchor_field(node)
      selections = Array.wrap(yield)
      selections.prepend(GraphQL::Language::Nodes::Field.new(field_alias: node.alias || node.name, name: GQL_TYPENAME))
      selections
    end

    # abstract positions insert a mapping of possible type outcomes with their respective transformations
    def with_typed_condition(parent_type, fragment_type, scope_type)
      possible_types = @schema.possible_types(parent_type) & @schema.possible_types(fragment_type)

      if scope_type == NATIVE_SCOPE && parent_type.kind.abstract? && fragment_type != parent_type
        @transform_map.type_breadcrumb(possible_types.map(&:graphql_name)) do
          results = Array.wrap(yield)
          results << GraphQL::Language::Nodes::Field.new(field_alias: HINT_TYPENAME, name: GQL_TYPENAME)
          results
        end
      elsif scope_type == METAOBJECT_SCOPE && MetafieldTypeResolver.mixed_reference_type?(parent_type.graphql_name)
        possible_values = possible_types.map { directive_kwargs(_1.directives, "metaobject")[:type] }
        @transform_map.type_breadcrumb(possible_values, map_all_fields: true) do
          results = Array.wrap(yield)
          results << GraphQL::Language::Nodes::Field.new(field_alias: HINT_TYPENAME, name: "type")
          results
        end
      else
        yield
      end
    end

    # connections must map transformations through possible `edges -> node` and `nodes` pathways
    def build_connection_selections(conn_type, conn_node)
      conn_node_type = @query.get_field(conn_type, "nodes").type.unwrap
      conn_node.selections.map do |node|
        @transform_map.field_breadcrumb(node) do
          case node.name
          when "edges"
            edges_selections = node.selections.map do |n|
              @transform_map.field_breadcrumb(n) do
                case n.name
                when "node"
                  n.merge(selections: yield(conn_node_type, n.selections))
                when GQL_TYPENAME
                  edge_type = @query.get_field(conn_type, "edges").type.unwrap
                  @transform_map.apply_field_transform(FieldTransform.new(STATIC_TYPENAME_TRANSFORM, value: edge_type.graphql_name))
                  n
                else
                  n
                end
              end
            end
            node.merge(selections: edges_selections)
          when "nodes"
            node.merge(selections: yield(conn_node_type, node.selections))
          when GQL_TYPENAME
            @transform_map.apply_field_transform(FieldTransform.new(STATIC_TYPENAME_TRANSFORM, value: conn_type.graphql_name))
            node
          else
            node
          end
        end
      end
    end

    def build_metaobject_query(parent_type, node, scope_ns: nil)
      return build_typename(parent_type, node, scope_type: EXTENSIONS_SCOPE, scope_ns: scope_ns) if node.name == GQL_TYPENAME

      field_type = @query.get_field(parent_type, node.name).type.unwrap
      return node unless MetafieldTypeResolver.connection_type?(field_type.graphql_name)

      node_type = @query.get_field(field_type, "nodes").type.unwrap
      metaobject_type = directive_kwargs(node_type.directives, "metaobject")&.dig(:type)
      return node unless metaobject_type

      selections = build_connection_selections(field_type, node) do |conn_node_type, conn_node_selections|
        transform_scope(conn_node_type, conn_node_selections, scope_type: METAOBJECT_SCOPE)
      end

      GraphQL::Language::Nodes::Field.new(
        field_alias: "#{RESERVED_PREFIX}#{scope_ns}_#{node.alias || node.name}",
        name: "metaobjects",
        arguments: [*node.arguments, GraphQL::Language::Nodes::Argument.new(name: "type", value: metaobject_type)],
        selections: selections,
      )
    end

    def build_metafield(parent_type, node, scope_type:, scope_ns: nil)
      return build_typename(parent_type, node, scope_type: scope_type, scope_ns: scope_ns) if node.name == GQL_TYPENAME

      field = @query.get_field(parent_type, node.name)
      metafield_attrs = directive_kwargs(field.directives, "metafield")
      return node unless metafield_attrs

      type_name = metafield_attrs[:type]
      is_list = MetafieldTypeResolver.list?(type_name)
      is_reference = MetafieldTypeResolver.reference?(type_name)
      field_alias = "#{scope_type == EXTENSIONS_SCOPE ? "#{RESERVED_PREFIX}#{scope_ns}_" : ""}#{node.alias || node.name}"

      selection = if is_reference && is_list
        @transform_map.apply_field_transform(FieldTransform.new(type_name))
        selections = build_connection_selections(field.type.unwrap, node) do |conn_node_type, conn_node_selections|
          build_metafield_reference(conn_node_type, conn_node_selections)
        end

        GraphQL::Language::Nodes::Field.new(
          name: "references",
          arguments: node.arguments,
          selections: selections,
        )
      elsif is_reference
        @transform_map.apply_field_transform(FieldTransform.new(type_name))
        GraphQL::Language::Nodes::Field.new(
          name: "reference",
          selections: build_metafield_reference(field.type.unwrap, node.selections),
        )
      else
        @transform_map.apply_field_transform(
          FieldTransform.new(
            type_name,
            selections: extract_value_object_selection(node.selections).presence,
          )
        )
        GraphQL::Language::Nodes::Field.new(name: "jsonValue")
      end

      GraphQL::Language::Nodes::Field.new(
        field_alias: field_alias,
        name: scope_type == EXTENSIONS_SCOPE ? "metafield" : "field",
        arguments: [GraphQL::Language::Nodes::Argument.new(name: "key", value: metafield_attrs[:key])],
        selections: Array.wrap(selection),
      )
    end

    def build_metafield_reference(reference_type, input_selections)
      result = if MetafieldTypeResolver.metaobject_type?(reference_type.graphql_name) ||
        MetafieldTypeResolver.mixed_reference_type?(reference_type.graphql_name)
        GraphQL::Language::Nodes::InlineFragment.new(
          type: GraphQL::Language::Nodes::TypeName.new(name: "Metaobject"),
          selections: transform_scope(reference_type, input_selections, scope_type: METAOBJECT_SCOPE),
        )
      else
        GraphQL::Language::Nodes::InlineFragment.new(
          type: GraphQL::Language::Nodes::TypeName.new(name: reference_type.graphql_name),
          selections: transform_scope(reference_type, input_selections),
        )
      end

      Array.wrap(result)
    end

    # build a __typename that must be transformed to match the schema of custom scopes
    def build_typename(parent_type, node, scope_type:, scope_ns: nil)
      field_name = node.alias || node.name
      case scope_type
      when EXTENSIONS_SCOPE
        @transform_map.apply_field_transform(FieldTransform.new(STATIC_TYPENAME_TRANSFORM, value: parent_type.graphql_name))
        return GraphQL::Language::Nodes::Field.new(
          field_alias: "#{RESERVED_PREFIX}#{scope_ns}_#{field_name}",
          name: GQL_TYPENAME,
        )
      when METAOBJECT_SCOPE
        @transform_map.apply_field_transform(FieldTransform.new(METAOBJECT_TYPENAME_TRANSFORM))
        return GraphQL::Language::Nodes::Field.new(
          field_alias: field_name,
          name: "type", # transform metaobject type: taco -> TacoMetaobject
        )
      else
        node
      end
    end

    # build selections for value object types (Money, Volume, Dimension)
    # these are always concrete, so can safely traverse fragment selections without type awareness
    def extract_value_object_selection(selections, acc = [])
      selections.each do |node|
        case node
        when GraphQL::Language::Nodes::Field
          acc << [node.alias, node.name].tap(&:compact!).join(":")
        when GraphQL::Language::Nodes::InlineFragment
          extract_value_object_selection(node.selections, acc)
        when GraphQL::Language::Nodes::FragmentSpread
          extract_value_object_selection(@query.fragments[node.name].selections, acc)
        end
      end
      acc
    end

    # eliminate redundant ___typehint selections (purely cosmetic)
    def compact_typehints(nodes)
      typehint_node = nil
      nodes.reject! do |node|
        is_typehint = node.is_a?(GraphQL::Language::Nodes::Field) && node.alias == HINT_TYPENAME
        typehint_node = node if is_typehint
        is_typehint
      end
      nodes << typehint_node if typehint_node
      nodes
    end

    # pull kwargs from a given directive name (GraphQL Ruby lacks native apis for this)
    def directive_kwargs(directives, directive_name)
      directives.find { _1.graphql_name == directive_name }&.arguments&.keyword_arguments
    end
  end
end
