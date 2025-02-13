# frozen_string_literal: true

require_relative "shop_schema_composer/metafield_definition"
require_relative "shop_schema_composer/metaobject_definition"
require_relative "shop_schema_composer/metaschema_catalog"

module ShopSchemaClient
  class ShopSchemaComposer
    class MetafieldDirective < GraphQL::Schema::Directive
      graphql_name "metafield"
      locations FIELD_DEFINITION
      argument :key, String, required: true
      argument :type, String, required: true
    end

    attr_reader :schema_types

    def initialize(base_schema, catalog)
      @base_schema = base_schema
      @catalog = catalog

      introspection_names = @base_schema.introspection_system.types.keys
      @schema_types = @base_schema.types.reject! { |k, v| introspection_names.include?(k) }
    end

    def perform
      @base_schema.possible_types(@schema_types["HasMetafields"]).each do |native_type|
        build_native_type_extensions(native_type)
      end

      @catalog.metaobject_definitions.each do |metaobject_def|
        build_metaobject(metaobject_def)
      end

      builder = self
      Class.new(GraphQL::Schema) do
        directive(MetafieldDirective)
        add_type_and_traverse(builder.schema_types.values, root: false)
        orphan_types(builder.schema_types.values.select { |t| t.respond_to?(:kind) && t.kind.object? })
        query(builder.schema_types["QueryRoot"])
        mutation(builder.schema_types["MutationRoot"])
        own_orphan_types.clear
      end
    end

    def type_for_metafield_definition(field_def)
      is_list = field_def.list?
      case field_def.type
      when "boolean"
        @schema_types["Boolean"]
      when "color", "list.color"
        type = build_color_metatype
        is_list ? type.to_list_type : type
      when "collection_reference", "list.collection_reference"
        is_list ? @schema_types["Collection"] : @schema_types["Collection"]
      when "company_reference", "list.company_reference"
        is_list ? @schema_types["CompanyConnection"] : @schema_types["Company"]
      when "customer_reference", "list.customer_reference"
        is_list ? @schema_types["CustomerConnection"] : @schema_types["Customer"]
      when "date_time", "list.date_time"
        type = @schema_types["DateTime"]
        is_list ? type.to_list_type : type
      when "date", "list.date"
        type = @schema_types["Date"]
        is_list ? type.to_list_type : type
      when "dimension", "list.dimension"
        type = build_dimension_metatype
        is_list ? type.to_list_type : type
      when "file_reference", "list.file_reference"
        GraphQL::Schema::BUILT_IN_TYPES["Boolean"] # fixme
      when "id"
        @schema_types["ID"]
      when "json"
        @schema_types["JSON"]
      when "language"
        @schema_types["LanguageCode"]
      when "link", "list.link"
        type = @schema_types["Link"]
        is_list ? type.to_list_type : type
      when "metaobject_reference", "list.metaobject_reference"
        metaobject_def = field_def.metaobject_definition(@catalog)
        if metaobject_def
          metaobject_name = MetafieldTypeResolver.metaobject_typename(metaobject_def["type"])
          metaobject_conn_name = MetafieldTypeResolver.connection_typename(metaobject_name)
          GraphQL::Schema::LateBoundType.new(is_list ? metaobject_conn_name : metaobject_name)
        else
          raise "Invalid metaobject_reference for `#{field_def.key}`"
        end
      when "mixed_reference", "list.mixed_reference"
        @schema_types["Metaobject"]
      when "money"
        @schema_types["MoneyV2"]
      when "multi_line_text_field"
        @schema_types["String"]
      when "number_decimal", "list.number_decimal"
        type = @schema_types["Float"]
        is_list ? type.to_list_type : type
      when "number_integer", "list.number_integer"
        type = @schema_types["Int"]
        is_list ? type.to_list_type : type
      when "order_reference"
        @schema_types["Order"]
      when "page_reference", "list.page_reference"
        is_list ? @schema_types["PageConnection"] : @schema_types["Page"]
      when "product_reference", "list.product_reference"
        is_list ? @schema_types["ProductConnection"] : @schema_types["Product"]
      when "product_taxonomy_value_reference", "list.product_taxonomy_value_reference"
        is_list ? @schema_types["TaxonomyValueConnection"] : @schema_types["TaxonomyValue"]
      when "rating", "list.rating"
        type = build_rating_metatype
        is_list ? type.to_list_type : type
      when "rich_text_field"
        build_rich_text_metatype
      when "single_line_text_field", "list.single_line_text_field"
        type = @schema_types["String"]
        is_list ? type.to_list_type : type
      when "url", "list.url"
        type = @schema_types["URL"]
        is_list ? type.to_list_type : type
      when "variant_reference", "list.variant_reference"
        is_list ? @schema_types["ProductVariantConnection"] : @schema_types["ProductVariant"]
      when "volume", "list.volume"
        type = build_volume_metatype
        is_list ? type.to_list_type : type
      when "weight", "list.weight"
        type = @schema_types["Weight"]
        is_list ? type.to_list_type : type
      else
        raise "Unknown metafield type `#{metafield_type}`"
      end
    end

    def build_native_type_extensions(native_type)
      metafield_definitions = @catalog.metafields_for_type(native_type.graphql_name)
      return unless metafield_definitions&.any?

      builder = self
      extensions_typename = MetafieldTypeResolver.extensions_typename(native_type.graphql_name)
      type = @schema_types[extensions_typename] = Class.new(GraphQL::Schema::Object) do
        graphql_name(extensions_typename)
        description("Projected metafield extensions for the #{native_type.graphql_name} type.")

        metafield_definitions.each do |metafield_def|
          builder.build_object_field(metafield_def, self)
        end
      end

      native_type.field(
        :extensions,
        type,
        null: false,
        description: "Projected metafield extensions.",
      )
    end

    def build_object_field(metafield_def, owner)
      builder = self
      type = type_for_metafield_definition(metafield_def)
      owner.field(
        metafield_def.key.to_sym,
        type,
        description: metafield_def.description,
        connection: false, # don't automatically build connection configuration
      ) do |f|
        f.directive(MetafieldDirective, key: metafield_def.key, type: metafield_def.type)
        if MetafieldTypeResolver.connection_type?(type.unwrap.graphql_name)
          f.argument(:first, builder.schema_types["Int"], required: false)
          f.argument(:last, builder.schema_types["Int"], required: false)
          f.argument(:before, builder.schema_types["String"], required: false)
          f.argument(:after, builder.schema_types["String"], required: false)
        end
      end
    end

    def build_metaobject(metaobject_def)
      builder = self
      metaobject_typename = MetafieldTypeResolver.metaobject_typename(metaobject_def.type)
      metaobject_type = @schema_types[metaobject_typename] = Class.new(GraphQL::Schema::Object) do
        graphql_name(metaobject_typename)
        description(metaobject_def.description)
        field(:id, builder.schema_types["ID"], null: false)

        metaobject_def.fields.each do |metafield_def|
          builder.build_object_field(metafield_def, self)
        end
      end

      connection_type_name = MetafieldTypeResolver.connection_typename(metaobject_type.graphql_name)
      @schema_types[metaobject_type.edge_type.graphql_name] = metaobject_type.edge_type
      @schema_types[connection_type_name] = Class.new(GraphQL::Schema::Object) do
        graphql_name(connection_type_name)
        field :edges, metaobject_type.edge_type.to_non_null_type.to_list_type, null: false
        field :nodes, metaobject_type.to_non_null_type.to_list_type, null: false
        field :page_info, builder.schema_types["PageInfo"], null: false
      end
    end

    def build_color_metatype
      @schema_types[MetafieldTypeResolver::COLOR_TYPENAME] ||= Class.new(GraphQL::Schema::Scalar) do
        graphql_name(MetafieldTypeResolver::COLOR_TYPENAME)
        description("A hexadecimal color code.")
      end
    end

    def build_rich_text_metatype
      @schema_types[MetafieldTypeResolver::RICH_TEXT_TYPENAME] ||= Class.new(GraphQL::Schema::Scalar) do
        graphql_name(MetafieldTypeResolver::RICH_TEXT_TYPENAME)
        description("A parsed rich text data structure in JSON format.")
      end
    end

    def build_dimension_metatype
      builder = self
      @schema_types[MetafieldTypeResolver::DIMENSION_TYPENAME] ||= Class.new(GraphQL::Schema::Object) do
        graphql_name(MetafieldTypeResolver::DIMENSION_TYPENAME)
        description("A dimensional measurement.")
        field :unit, builder.schema_types["String"]
        field :value, builder.schema_types["Float"]
      end
    end

    def build_rating_metatype
      builder = self
      @schema_types[MetafieldTypeResolver::RATING_TYPENAME] ||= Class.new(GraphQL::Schema::Object) do
        graphql_name(MetafieldTypeResolver::RATING_TYPENAME)
        description("A rating value.")
        field :max, builder.schema_types["Float"]
        field :min, builder.schema_types["Float"]
        field :value, builder.schema_types["Float"]
      end
    end

    def build_volume_metatype
      builder = self
      @schema_types[MetafieldTypeResolver::VOLUME_TYPENAME] ||= Class.new(GraphQL::Schema::Object) do
        graphql_name(MetafieldTypeResolver::VOLUME_TYPENAME)
        description("A volumetric measurement.")
        field :unit, builder.schema_types["String"]
        field :value, builder.schema_types["Float"]
      end
    end
  end
end
