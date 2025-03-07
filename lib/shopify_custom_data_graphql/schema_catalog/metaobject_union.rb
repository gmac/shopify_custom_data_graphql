# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class CustomDataCatalog
    class MetaobjectUnion
      attr_reader :metaobject_definitions

      def initialize(metaobject_defs)
        @metaobject_definitions = metaobject_defs.sort_by(&:typename)
      end

      def ==(other)
        @metaobject_definitions == other.metaobject_definitions
      end

      def typename
        @typename ||= begin
          member_names = @metaobject_definitions.map(&:typename)
          member_identity = Digest::MD5.hexdigest(member_names.join("/")).slice(0..3)
          "#{MetafieldTypeResolver::MIXED_REFERENCE_TYPE_PREFIX}#{member_identity.upcase}"
        end
      end
    end
  end
end
