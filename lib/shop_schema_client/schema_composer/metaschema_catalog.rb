# frozen_string_literal: true

module ShopSchemaClient
  class SchemaComposer
    class MetaschemaCatalog
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

      def metafields_for_type(typename)
        fields_for_owner = @metafields_by_owner[typename.underscore.upcase]
        fields_for_owner ? fields_for_owner.values : []
      end
    end
  end
end
