class ShopSchemaComposer
  class MetafieldDirective < GraphQL::Schema::Directive
    graphql_name "metafield"
    locations FIELD_DEFINITION
    argument :key, String, required: true
    argument :type, String, required: true
  end

  attr_reader :schema_types

  def initialize(meta_types, admin_schema)
    @meta_types = meta_types
    @admin_schema = admin_schema

    introspection_names = @admin_schema.introspection_system.types.keys
    @schema_types = @admin_schema.types.reject! { |k, v| introspection_names.include?(k) }

    @metaobject_definitions_by_id = @meta_types.dig("data", "metaobjectDefinitions", "nodes").each_with_object({}) do |obj, memo|
      obj.delete("metaobjects")
      memo[obj["id"]] = obj
    end
  end

  def perform
    @admin_schema.possible_types(@schema_types["HasMetafields"]).each do |native_type|
      build_native_type_extensions(native_type)
    end

    @metaobject_definitions_by_id.each_value do |metaobject_def|
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
    metafield_type = field_def.dig("type", "name")
    list = MetafieldTypeResolver.list?(metafield_type)
    case metafield_type
    when "boolean"
      @schema_types["Boolean"]
    when "color", "list.color"
      type = build_color_metatype
      list ? type.to_list_type : type
    when "collection_reference", "list.collection_reference"
      list ? @schema_types["CollectionConnection"] : @schema_types["Collection"]
    when "company_reference", "list.company_reference"
      list ? @schema_types["CompanyConnection"] : @schema_types["Company"]
    when "customer_reference", "list.customer_reference"
      list ? @schema_types["CustomerConnection"] : @schema_types["Customer"]
    when "date_time", "list.date_time"
      type = @schema_types["DateTime"]
      list ? type.to_list_type : type
    when "date", "list.date"
      type = @schema_types["Date"]
      list ? type.to_list_type : type
    when "dimension", "list.dimension"
      type = build_dimension_metatype
      list ? type.to_list_type : type
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
      list ? type.to_list_type : type
    when "metaobject_reference", "list.metaobject_reference"
      metaobject_id = field_def["validations"].find { _1["name"] == "metaobject_definition_id" }["value"]
      metaobject_def = @metaobject_definitions_by_id[metaobject_id]
      if metaobject_def
        metaobject_name = MetafieldTypeResolver.metaobject_typename(metaobject_def["type"])
        GraphQL::Schema::LateBoundType.new(list ? "#{metaobject_name}Connection" : metaobject_name)
      else
        raise "invalid metaobject_reference for #{field_def["key"]}"
      end
    when "mixed_reference", "list.mixed_reference"
      GraphQL::Schema::BUILT_IN_TYPES["Boolean"] # fixme
    when "money"
      @schema_types["MoneyV2"]
    when "multi_line_text_field"
      @schema_types["String"]
    when "number_decimal", "list.number_decimal"
      type = @schema_types["Float"]
      list ? type.to_list_type : type
    when "number_integer", "list.number_integer"
      type = @schema_types["Int"]
      list ? type.to_list_type : type
    when "order_reference"
      @schema_types["Order"]
    when "page_reference", "list.page_reference"
      list ? @schema_types["PageConnection"] : @schema_types["Page"]
    when "product_reference", "list.product_reference"
      list ? @schema_types["ProductConnection"] : @schema_types["Product"]
    when "product_taxonomy_value_reference", "list.product_taxonomy_value_reference"
      list ? @schema_types["TaxonomyValueConnection"] : @schema_types["TaxonomyValue"]
    when "rating", "list.rating"
      type = build_rating_metatype
      list ? type.to_list_type : type
    when "rich_text_field"
      GraphQL::Schema::BUILT_IN_TYPES["Boolean"] # fixme
    when "single_line_text_field", "list.single_line_text_field"
      type = @schema_types["String"]
      list ? type.to_list_type : type
    when "url", "list.url"
      type = @schema_types["URL"]
      list ? type.to_list_type : type
    when "variant_reference", "list.variant_reference"
      list ? @schema_types["ProductVariantConnection"] : @schema_types["ProductVariant"]
    when "volume", "list.volume"
      type = build_volume_metatype
      list ? type.to_list_type : type
    when "weight", "list.weight"
      type = @schema_types["Weight"]
      list ? type.to_list_type : type
    else
      raise "Unknown metafield type `#{metafield_type}`"
    end
  end

  def build_native_type_extensions(native_type)
    metafield_definitions = @meta_types.dig("data", "#{native_type.graphql_name.downcase}Fields", "nodes")
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
    type = type_for_metafield_definition(metafield_def)
    builder_types = @schema_types
    owner.field(
      metafield_def["key"].to_sym,
      type,
      description: metafield_def["description"],
      connection: false, # don't automatically build connection configuration
    ) do |f|
      f.directive(MetafieldDirective, key: metafield_def["key"], type: metafield_def.dig("type", "name"))
      if type.unwrap.graphql_name.end_with?("Connection")
        f.argument(:first, builder_types["Int"], required: false)
        f.argument(:last, builder_types["Int"], required: false)
        f.argument(:before, builder_types["String"], required: false)
        f.argument(:after, builder_types["String"], required: false)
      end
    end
  end

  def build_metaobject(metaobject_def)
    builder = self
    metaobject_typename = MetafieldTypeResolver.metaobject_typename(metaobject_def["type"])
    metaobject_type = @schema_types[metaobject_typename] = Class.new(GraphQL::Schema::Object) do
      graphql_name(metaobject_typename)
      description(metaobject_def["description"])
      field(:id, builder.schema_types["ID"], null: false)

      metaobject_def["fieldDefinitions"].each do |metafield_def|
        builder.build_object_field(metafield_def, self)
      end
    end

    @schema_types[metaobject_type.edge_type.graphql_name] = metaobject_type.edge_type
    @schema_types["#{metaobject_type.graphql_name}Connection"] = Class.new(GraphQL::Schema::Object) do
      graphql_name("#{metaobject_type.graphql_name}Connection")
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
