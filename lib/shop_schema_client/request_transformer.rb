# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    def initialize(query)
      @query = query
      @schema = query.schema
      @owner_types = @schema.possible_types(@schema.get_type("HasMetafields")).to_set
      @new_fragments = {}
    end

    def perform
      op = @query.selected_operation
      parent_type = @query.root_type_for_operation(op.operation_type)
      op = op.merge(selections: transform_scope(parent_type, op.selections))
      GraphQL::Language::Nodes::Document.new(definitions: [op, *@new_fragments.values])
    end

    private

    def transform_scope(parent_type, input_selections, scope_type: :native)
      new_selections = input_selections.flat_map do |node|
        case node
        when GraphQL::Language::Nodes::Field
          if scope_type == :extensions || scope_type == :metaobject
            build_metafield(parent_type, node, scope_type: scope_type)
          elsif scope_type == :native && node.name == "extensions" && @owner_types.include?(parent_type)
            next_type = parent_type.get_field(node.name).type.unwrap
            transform_scope(next_type, node.selections, scope_type: :extensions)
          elsif node.selections&.any?
            next_type = parent_type.get_field(node.name).type.unwrap
            node.merge(selections: transform_scope(next_type, node.selections))
          else
            node
          end

        when GraphQL::Language::Nodes::InlineFragment
          fragment_type = node.type.nil? ? parent_type : @schema.get_type(node.type.name)

          if MetafieldTypeResolver.extensions_type?(fragment_type.graphql_name)
            transform_scope(fragment_type, node.selections, scope_type: :extensions)
          elsif MetafieldTypeResolver.metaobject_type?(fragment_type.graphql_name)
            GraphQL::Language::Nodes::InlineFragment.new(
              type: GraphQL::Language::Nodes::TypeName.new(name: "Metaobject"),
              selections: transform_scope(fragment_type, node.selections, scope_type: :metaobject),
            )
          else
            GraphQL::Language::Nodes::InlineFragment.new(
              type: GraphQL::Language::Nodes::TypeName.new(name: fragment_type.graphql_name),
              selections: transform_scope(fragment_type, node.selections),
            )
          end

        when GraphQL::Language::Nodes::FragmentSpread
          unless @new_fragments[node.name]
            fragment_def = @query.fragments[node.name]
            fragment_type = @schema.get_type(fragment_def.type.name)
            fragment_type_name = fragment_type.graphql_name

            fragment_selections = if MetafieldTypeResolver.extensions_type?(fragment_type.graphql_name)
              fragment_type_name = fragment_type_name.sub(MetafieldTypeResolver::EXTENSIONS_TYPE_SUFFIX, "")
              transform_scope(fragment_type, fragment_def.selections, scope_type: :extensions)
            elsif MetafieldTypeResolver.metaobject_type?(fragment_type.graphql_name)
              fragment_type_name = "Metaobject"
              transform_scope(fragment_type, fragment_def.selections, scope_type: :metaobject)
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

      if parent_type.kind.abstract?
        new_selections << GraphQL::Language::Nodes::Field.new(
          field_alias: "__exp__typename",
          name: "__typename",
        )
      end

      new_selections
    end

    def build_metafield(parent_type, node, scope_type:)
      if node.name == "__typename"
        return GraphQL::Language::Nodes::Field.new(
          field_alias: "__#{ scope_type.to_s[0] }name_#{node.alias || node.name}",
          name: scope_type == :metaobject ? "type" : "__typename",
        )
      end

      field = parent_type.get_field(node.name)
      metafield_attrs = field.directives.find { _1.graphql_name == "metafield" }&.arguments&.keyword_arguments
      return node unless metafield_attrs

      type_name = metafield_attrs[:type]
      is_list = MetafieldTypeResolver.list?(type_name)
      is_reference = MetafieldTypeResolver.reference?(type_name)
      field_alias = "#{scope_type == :extensions ? "__ext_" : ""}#{node.alias || node.name}"
      next_type = parent_type.get_field(node.name).type.unwrap

      selections = if is_reference && is_list
        conn_node_type = next_type.get_field("nodes").type.unwrap
        conn_selections = node.selections.map do |conn_node|
          case conn_node.name
          when "edges"
            edges_selections = conn_node.selections.map do |n|
              n.name == "node" ? n.merge(selections: build_metafield_reference(conn_node_type, n.selections)) : n
            end
            conn_node.merge(selections: edges_selections)
          when "nodes"
            conn_node.merge(selections: build_metafield_reference(conn_node_type, conn_node.selections))
          else
            conn_node
          end
        end

        [
          GraphQL::Language::Nodes::Field.new(
            name: "references",
            arguments: node.arguments,
            selections: conn_selections,
          )
        ]
      elsif is_reference
        [
          GraphQL::Language::Nodes::Field.new(
            name: "reference",
            selections: build_metafield_reference(next_type, node.selections),
          )
        ]
      else
        [GraphQL::Language::Nodes::Field.new(name: "value")]
      end

      GraphQL::Language::Nodes::Field.new(
        field_alias: field_alias,
        name: scope_type == :metaobject ? "field" : "metafield",
        arguments: [GraphQL::Language::Nodes::Argument.new(name: "key", value: metafield_attrs[:key])],
        selections: selections,
      )
    end

    def build_metafield_reference(reference_type, input_selections)
      if MetafieldTypeResolver.metaobject_type?(reference_type.graphql_name)
        [
          GraphQL::Language::Nodes::InlineFragment.new(
            type: GraphQL::Language::Nodes::TypeName.new(name: "Metaobject"),
            selections: transform_scope(reference_type, input_selections, scope_type: :metaobject),
          )
        ]
      else
        [
          GraphQL::Language::Nodes::InlineFragment.new(
            type: GraphQL::Language::Nodes::TypeName.new(name: reference_type.graphql_name),
            selections: transform_scope(reference_type, input_selections),
          )
        ]
      end
    end
  end
end
