# frozen_string_literal: true

require_relative "schema_catalog/metafield_definition"
require_relative "schema_catalog/metaobject_definition"
require_relative "schema_catalog/metaobject_union"
require_relative "schema_catalog/load"

module ShopSchemaClient
  class SchemaCatalog
    OWNER_ENUMS_BY_TYPE = {
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

    attr_accessor :app_id
    attr_reader :metafields_by_owner

    def initialize(app_id: nil, base_namespaces: ["custom"], scoped_namespaces: ["my_fields"])
      @app_id = app_id
      @base_namespaces = base_namespaces.map { format_metafield_namespace(_1, app_id) }
      @scoped_namespaces = scoped_namespaces.map { format_metafield_namespace(_1, app_id) }
      @metafields_by_owner = {}
      @metaobjects_by_id = {}
    end

    def add_metafield(metafield)
      metafield = MetafieldDefinition.from_graphql(metafield) unless metafield.is_a?(MetafieldDefinition)

      if matches_metafield_namespace?(@scoped_namespaces, metafield.namespace)
        if metafield.namespace.start_with?("app--")
          _, app_id, app_ns = metafield.namespace.split("--")
          metafield.schema_namespace = []
          metafield.schema_namespace << "app#{app_id}" if app_id.to_i != @app_id
          metafield.schema_namespace << app_ns if app_ns
        else
          metafield.schema_namespace = [metafield.namespace]
        end
      elsif !matches_metafield_namespace?(@base_namespaces, metafield.namespace)
        return nil
      end

      @metafields_by_owner[metafield.owner_type] ||= []
      @metafields_by_owner[metafield.owner_type] << metafield
      metafield
    end

    def add_metaobject(metaobject)
      metaobject = MetaobjectDefinition.from_graphql(metaobject) unless metaobject.is_a?(MetaobjectDefinition)
      metaobject.app_context = @app_id
      @metaobjects_by_id[metaobject.id] = metaobject
    end

    def metaobject_definitions
      @metaobjects_by_id.values
    end

    def metaobject_by_id(id)
      @metaobjects_by_id[id]
    end

    def metafields_for_type(graphql_name)
      mapped_name = OWNER_ENUMS_BY_TYPE.fetch(graphql_name, graphql_name.underscore.upcase)
      @metafields_by_owner.fetch(mapped_name, [])
    end

    private

    def matches_metafield_namespace?(candidates, namespace)
      candidates.each do |c|
        return true if c == namespace || c == "*"
        return true if c.end_with?("*") && namespace.start_with?(c[0..-2])
      end
      false
    end

    def format_metafield_namespace(namespace, app_id = nil)
      if app_id && namespace.start_with?("$app:")
        namespace.sub("$app:", "app--#{app_id}--")
      elsif app_id && namespace == "$app"
        "app--#{app_id}"
      else
        namespace
      end
    end
  end
end
