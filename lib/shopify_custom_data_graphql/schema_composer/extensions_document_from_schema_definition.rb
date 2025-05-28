# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class SchemaComposer
    class ExtensionsDocumentFromSchemaDefinition < GraphQL::Language::DocumentFromSchemaDefinition
      def initialize(schema, base_schema)
        super(schema)
        @base_schema = base_schema
      end

      def build_directive_nodes(all_directives)
        super(all_directives.reject { @base_schema.directives.key?(_1.graphql_name) })
      end

      def build_type_definition_nodes(all_types)
        types_with_extensions = [@types.query_root]
          .concat(@types.possible_types(@types.type("HasMetafields")))
          .to_set

        all_types = all_types
          .reject { |type| type.introspection? }
          .reject { |type| type.kind.scalar? && type.default_scalar? }
          .reject { |type| @base_schema.get_type(type.graphql_name) && !types_with_extensions.include?(type) }

        definitions = all_types.filter_map do |type|
          if types_with_extensions.include?(type)
            extension_field = @types.fields(type).find { _1.graphql_name == "extensions" }
            if extension_field
              GraphQL::Language::Nodes::ObjectTypeExtension.new(
                name: type.graphql_name,
                interfaces: [],
                fields: build_field_nodes([extension_field]),
              )
            end
          else
            build_type_definition_node(type)
          end
        end

        if @schema.schema_directives.any?
          definitions << GraphQL::Language::Nodes::SchemaExtension.new(
            directives: definition_directives(@schema, :schema_directives),
          )
        end

        definitions
      end

      def include_schema_node?
        false
      end
    end
  end
end
