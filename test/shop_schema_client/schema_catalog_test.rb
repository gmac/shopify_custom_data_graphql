# frozen_string_literal: true

require "test_helper"

describe "SchemaCatalog" do
  SchemaCatalog = ShopSchemaClient::SchemaCatalog

  BASE_METAFIELD = {
    "key" => "pizza_size",
    "type" => { "name" => "dimension" },
    "ownerType" => "PRODUCT",
  }

  BASE_METAOBJECT = {
    "id" => "1",
    "fieldDefinitions" => [],
  }

  def test_formats_base_and_scoped_namespaces
    catalog = SchemaCatalog.new(
      base_namespaces: ["custom"],
      scoped_namespaces: ["my_fields"],
    )

    mf = catalog.add_metafield({ "namespace" => "custom" }.merge!(BASE_METAFIELD))
    assert_equal "custom.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "my_fields.pizza_size", mf.reference_key
    assert_equal "myFields_pizzaSize", mf.schema_key
  end

  def test_formats_base_and_scoped_namespaces_for_app_aliases
    catalog = SchemaCatalog.new(
      base_namespaces: ["$app", "$app:base"],
      scoped_namespaces: ["$app:my_fields"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--base" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--base.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--my_fields.pizza_size", mf.reference_key
    assert_equal "myFields_pizzaSize", mf.schema_key
  end

  def test_formats_base_and_scoped_namespaces_for_current_app
    catalog = SchemaCatalog.new(
      base_namespaces: ["app--123--base"],
      scoped_namespaces: ["app--123", "app--123--my_fields"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "app--123--base" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--base.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--my_fields.pizza_size", mf.reference_key
    assert_equal "myFields_pizzaSize", mf.schema_key
  end

  def test_formats_no_app_concessions_without_app_id
    catalog = SchemaCatalog.new(
      base_namespaces: ["app--123--base"],
      scoped_namespaces: ["app--123", "app--123--my_fields"],
      app_id: nil,
    )

    mf = catalog.add_metafield({ "namespace" => "app--123--base" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--base.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "app123_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--my_fields.pizza_size", mf.reference_key
    assert_equal "app123_myFields_pizzaSize", mf.schema_key
  end

  def test_formats_base_and_scoped_namespaces_for_non_current_app
    catalog = SchemaCatalog.new(
      base_namespaces: ["app--456--base"],
      scoped_namespaces: ["app--456", "app--456--my_fields"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "app--456--base" }.merge!(BASE_METAFIELD))
    assert_equal "app--456--base.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456" }.merge!(BASE_METAFIELD))
    assert_equal "app--456.pizza_size", mf.reference_key
    assert_equal "app456_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456--my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "app--456--my_fields.pizza_size", mf.reference_key
    assert_equal "app456_myFields_pizzaSize", mf.schema_key
  end

  def test_formats_base_namespaces_for_full_wildcards
    catalog = SchemaCatalog.new(
      base_namespaces: ["*"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "custom" }.merge!(BASE_METAFIELD))
    assert_equal "custom.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--bakery" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--bakery.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456" }.merge!(BASE_METAFIELD))
    assert_equal "app--456.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456--bakery" }.merge!(BASE_METAFIELD))
    assert_equal "app--456--bakery.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key
  end

  def test_formats_scoped_namespaces_for_full_wildcards
    catalog = SchemaCatalog.new(
      scoped_namespaces: ["*"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "custom" }.merge!(BASE_METAFIELD))
    assert_equal "custom.pizza_size", mf.reference_key
    assert_equal "custom_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--bakery" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--bakery.pizza_size", mf.reference_key
    assert_equal "bakery_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456" }.merge!(BASE_METAFIELD))
    assert_equal "app--456.pizza_size", mf.reference_key
    assert_equal "app456_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456--bakery" }.merge!(BASE_METAFIELD))
    assert_equal "app--456--bakery.pizza_size", mf.reference_key
    assert_equal "app456_bakery_pizzaSize", mf.schema_key
  end

  def test_formats_partial_match_wildcard
    catalog = SchemaCatalog.new(
      scoped_namespaces: ["my_*", "app--*"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "my_fields" }.merge!(BASE_METAFIELD))
    assert_equal "my_fields.pizza_size", mf.reference_key
    assert_equal "myFields_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "my_prefs" }.merge!(BASE_METAFIELD))
    assert_equal "my_prefs.pizza_size", mf.reference_key
    assert_equal "myPrefs_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert_equal "app--123.pizza_size", mf.reference_key
    assert_equal "pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456" }.merge!(BASE_METAFIELD))
    assert_equal "app--456.pizza_size", mf.reference_key
    assert_equal "app456_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--sfoo" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--sfoo.pizza_size", mf.reference_key
    assert_equal "sfoo_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--456--sfoo" }.merge!(BASE_METAFIELD))
    assert_equal "app--456--sfoo.pizza_size", mf.reference_key
    assert_equal "app456_sfoo_pizzaSize", mf.schema_key

    assert !catalog.add_metafield({ "namespace" => "your_stuff" }.merge!(BASE_METAFIELD))
  end

  def test_formats_partial_match_wildcard_with_app_alias
    catalog = SchemaCatalog.new(
      scoped_namespaces: ["$app:*"],
      app_id: 123,
    )

    mf = catalog.add_metafield({ "namespace" => "app--123--sfoo" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--sfoo.pizza_size", mf.reference_key
    assert_equal "sfoo_pizzaSize", mf.schema_key

    mf = catalog.add_metafield({ "namespace" => "app--123--bar" }.merge!(BASE_METAFIELD))
    assert_equal "app--123--bar.pizza_size", mf.reference_key
    assert_equal "bar_pizzaSize", mf.schema_key

    assert !catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert !catalog.add_metafield({ "namespace" => "app--456--sfoo" }.merge!(BASE_METAFIELD))
  end

  def test_rejects_unmatched_namespaces
    catalog = SchemaCatalog.new(
      base_namespaces: ["custom", "$app"],
      scoped_namespaces: ["$app:bakery"],
      app_id: 123,
    )

    assert catalog.add_metafield({ "namespace" => "custom" }.merge!(BASE_METAFIELD))
    assert catalog.add_metafield({ "namespace" => "app--123" }.merge!(BASE_METAFIELD))
    assert catalog.add_metafield({ "namespace" => "app--123--bakery" }.merge!(BASE_METAFIELD))
    assert_equal 3, catalog.metafields_by_owner["PRODUCT"].length

    assert !catalog.add_metafield({ "namespace" => "nope" }.merge!(BASE_METAFIELD))
    assert !catalog.add_metafield({ "namespace" => "app--456" }.merge!(BASE_METAFIELD))
    assert !catalog.add_metafield({ "namespace" => "app--456--bakery" }.merge!(BASE_METAFIELD))
    assert_equal 3, catalog.metafields_by_owner["PRODUCT"].length
  end

  def test_formats_metaobject_types_without_app_context
    catalog = SchemaCatalog.new

    mo = catalog.add_metaobject({ "type" => "taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoMetaobject", mo.typename

    mo = catalog.add_metaobject({ "type" => "app--123--taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoApp123Metaobject", mo.typename

    mo = catalog.add_metaobject({ "type" => "app--456--taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoApp456Metaobject", mo.typename
  end

  def test_formats_metaobject_types_with_app_context
    catalog = SchemaCatalog.new(app_id: 123)

    mo = catalog.add_metaobject({ "type" => "taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoShopMetaobject", mo.typename

    mo = catalog.add_metaobject({ "type" => "app--123--taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoMetaobject", mo.typename

    mo = catalog.add_metaobject({ "type" => "app--456--taco" }.merge!(BASE_METAOBJECT))
    assert_equal "TacoApp456Metaobject", mo.typename
  end
end
