# frozen_string_literal: true

module ShopSchemaClient
  class SchemaComposer
    class MetaschemaCatalog
      OWNER_TYPES = {
        "CartTransform" => "CARTTRANSFORM",
        "CustomerSegmentMember" => "CUSTOMER",
        "DiscountAutomaticNode" => "DISCOUNT",
        "DiscountCodeNode" => "DISCOUNT",
        "DiscountNode" => "DISCOUNT",
        "DraftOrder" => "DRAFTORDER",
        "GiftCardCreditTransaction" => "GIFT_CARD_TRANSACTION",
        "GiftCardDebitTransaction" => "GIFT_CARD_TRANSACTION",
        "Image" => "MEDIA_IMAGE",
        "ProductVariant" => "PRODUCTVARIANT",
      }.freeze

      def initialize
        @metafields_by_owner = {}
        @metaobjects_by_id = {}
      end

      def add_metaobjects(metaobjects)
        metaobjects.each { @metaobjects_by_id[_1.id] = _1 }
      end

      def add_metafields(metafields)
        metafields.each do |f|
          @metafields_by_owner[f.owner_type] ||= {}
          @metafields_by_owner[f.owner_type][f.key] = f
        end
      end

      def metaobject_definitions
        @metaobjects_by_id.values
      end

      def metaobject_by_id(id)
        @metaobjects_by_id[id]
      end

      def metafields_for_type(graphql_name)
        mapped_name = OWNER_TYPES.fetch(graphql_name, graphql_name.underscore.upcase)
        fields_for_owner = @metafields_by_owner[mapped_name]
        fields_for_owner ? fields_for_owner.values : []
      end
    end
  end
end
