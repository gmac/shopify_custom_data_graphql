# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class CustomDataCatalog
    METAFIELD_GRAPHQL_ATTRS = %|
      fragment MetafieldAttrs on MetafieldDefinition {
        key
        namespace
        ownerType
        description
        type { name }
        validations {
          name
          value
        }
      }
    |

    class MetafieldDefinition
      class << self
        def from_graphql(metafield_def)
          new(
            key: metafield_def["key"],
            type: metafield_def.dig("type", "name"),
            namespace: metafield_def["namespace"],
            description: metafield_def["description"],
            validations: metafield_def["validations"],
            owner_type: metafield_def["ownerType"],
          )
        end
      end

      attr_reader :key, :type, :namespace, :description, :validations, :owner_type
      attr_accessor :schema_namespace

      def initialize(key:, type:, namespace:, description:, validations:, owner_type:)
        @key = key
        @type = type
        @namespace = namespace
        @description = description
        @validations = validations
        # need to handle irregulars...
        @owner_type = owner_type&.underscore&.upcase || "METAOBJECT"
      end

      def reference_key
        @reference_key ||= owner_type == "METAOBJECT" ? key : [namespace, key].tap(&:compact!).join(".")
      end

      def schema_key
        @schema_key ||= [*(schema_namespace || []), key].map! { _1.camelize(:lower) }.join("_")
      end

      def list?
        ShopifyCustomDataGraphQL::MetafieldTypeResolver.list?(type)
      end

      def reference?
        ShopifyCustomDataGraphQL::MetafieldTypeResolver.reference?(type)
      end

      def linked_metaobject(catalog)
        validation = validations.find { _1["name"] == "metaobject_definition_id" }
        catalog.metaobject_by_id(validation["value"]) if validation
      end

      def linked_metaobject_union(catalog)
        validation = validations.find { _1["name"] == "metaobject_definition_ids" }
        if validation
          validation = validation["value"]
          validation = JSON.parse(validation) if validation.is_a?(String)
          MetaobjectUnion.new(validation.map { catalog.metaobject_by_id(_1) })
        end
      end
    end
  end
end
