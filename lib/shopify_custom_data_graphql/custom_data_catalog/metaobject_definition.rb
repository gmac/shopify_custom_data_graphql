# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class CustomDataCatalog
    METAOBJECT_GRAPHQL_ATTRS = %|
      fragment MetaobjectAttrs on MetaobjectDefinition {
        id
        description
        name
        type
        fieldDefinitions {
          key
          description
          type { name }
          validations {
            name
            value
          }
        }
      }
    |

    MetaobjectDefinition = Struct.new(
      :id,
      :type,
      :description,
      :fields,
      :app_context,
      keyword_init: true
    ) do
      class << self
        def from_graphql(metaobject_def)
          new(
            id: metaobject_def["id"],
            type: metaobject_def["type"],
            description: metaobject_def["description"],
            fields: metaobject_def["fieldDefinitions"].map { MetafieldDefinition.from_graphql(_1) },
          )
        end
      end

      def typename
        @typename ||= MetafieldTypeResolver.metaobject_typename(type, app_id: app_context)
      end

      def connection_field
        @connection_field ||= typename.camelize(:lower).pluralize
      end
    end
  end
end
