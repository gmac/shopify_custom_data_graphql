# frozen_string_literal: true

module ShopSchemaClient
  class ResponseTransformer
    def initialize(shop_schema, document)
      @schema = shop_schema
      @owner_types = @schema.possible_types(@schema.get_type("HasMetafields")).to_set
      @document = document
    end

    def perform(result)
      op = @document.definitions.first
      transform_object_scope(result, @schema.query, op.selections, @schema.query.graphql_name)
    end

    private

    def transform_object_scope(raw_object, parent_type, selections, typename = nil)
      return nil if raw_object.nil?

      # @todo need some kind of automatically-resolved type hint to make abstracts work...
      typename ||= raw_object["_export__typename"]
      raw_object.delete("_export__typename")

      # shift all `__extensions__` fields into a dedicated scope
      scope_extensions!(raw_object) if @owner_types.include?(parent_type)

      is_metafields_scope = MetafieldTypeResolver.extensions_type?(parent_type.graphql_name) ||
        MetafieldTypeResolver.metaobject_type?(parent_type.graphql_name)

      selections.each do |node|
        case node
        when GraphQL::Language::Nodes::Field
          field_name = node.alias || node.name
          field = parent_type.get_field(node.name)
          node_type = unwrap_non_null(field.type)
          named_type = node_type.unwrap

          if is_metafields_scope && (metafield_attrs = field.directives.find { _1.graphql_name == "metafield" }&.arguments&.keyword_arguments)
            metafield_type = metafield_attrs[:type]
            raw_object[field_name] = MetafieldTypeResolver.resolve(metafield_type, raw_object[field_name], node.selections)

            # only continue traversing when following metafield references
            # otherwise, we can assume basic metafield value types are now fully resolved.
            next unless MetafieldTypeResolver.reference?(metafield_type)
          end

          if node_type.list?
            transform_list_scope(raw_object[field_name], node_type, node.selections)
          elsif named_type.kind.composite?
            transform_object_scope(raw_object[field_name], named_type, node.selections)
          end

        # # Need to handle fragments...
        # when GraphQL::Language::Nodes::InlineFragment
        #   fragment_type = node.type ? @supergraph.memoized_schema_types[node.type.name] : parent_type
        #   next unless typename_in_type?(typename, fragment_type)

        #   result = transform_object_scope(raw_object, fragment_type, node.selections, typename)
        #   return nil if result.nil?

        # when GraphQL::Language::Nodes::FragmentSpread
        #   fragment = @request.fragment_definitions[node.name]
        #   fragment_type = @supergraph.memoized_schema_types[fragment.type.name]
        #   next unless typename_in_type?(typename, fragment_type)

        #   result = transform_object_scope(raw_object, fragment_type, fragment.selections, typename)
        #   return nil if result.nil?

        else
          raise "Invalid node type"
        end
      end

      raw_object
    end

    def transform_list_scope(list_value, current_node_type, selections)
      return if list_value.nil?

      next_node_type = unwrap_non_null(current_node_type).of_type
      named_type = next_node_type.unwrap

      list_value.each do |list_item|
        if next_node_type.list?
          transform_list_scope(list_item, next_node_type, selections)
        elsif named_type.kind.composite?
          transform_object_scope(list_item, named_type, selections)
        end
      end
    end

    def scope_extensions!(raw_object)
      extensions_scope = nil
      raw_object.reject! do |key, value|
        next false unless key.start_with?("__extensions__")

        extensions_scope ||= {}
        extensions_scope[key.sub("__extensions__", "")] = value
        true
      end

      if extensions_scope
        raw_object["extensions"] = extensions_scope
      end
    end

    def unwrap_non_null(type)
      type = type.of_type while type.non_null?
      type
    end
  end
end
