# frozen_string_literal: true

require "test_helper"

describe "MetafieldTypeResolver" do
  def test_resolves_boolean
    assert_equal true, resolve_fixture("boolean")
  end

  def test_resolves_color
    assert_equal "#ff0000", resolve_fixture("color")
  end

  def test_resolves_color_list
    assert_equal ["#ff0000", "#0000ff"], resolve_fixture("list.color")
  end

  def test_resolves_date
    assert_equal "2025-02-26", resolve_fixture("date")
  end

  def test_resolves_date_list
    assert_equal ["2025-02-26", "2025-02-27"], resolve_fixture("list.date")
  end

  def test_resolves_date_time
    assert_equal "2025-02-27T02:00:00Z", resolve_fixture("date_time")
  end

  def test_resolves_date_time_list
    assert_equal ["2025-02-27T02:00:00Z", "2025-02-28T02:00:00Z"], resolve_fixture("list.date_time")
  end

  def test_resolves_dimension
    expected = { "unit" => "INCHES", "value" => 23.0 }
    assert_equal expected, resolve_fixture("dimension", ["unit", "value"])
  end

  def test_resolves_dimension_list
    expected = [
      {
        "unit" => "INCHES",
        "value" => 1.0,
      },
      {
        "unit" => "INCHES",
        "value" => 2.0,
      }
    ]
    assert_equal expected, resolve_fixture("list.dimension", ["unit", "value"])
  end

  def test_resolves_dimension_with_aliases_and_typename
    expected = { "u" => "INCHES", "v" => 23.0, "__typename" => "DimensionMetatype" }
    assert_equal expected, resolve_fixture("dimension", ["u:unit", "v:value", "__typename"])
  end

  def test_resolves_id
    assert_equal "r2d2-c3p0", resolve_fixture("id")
  end

  def test_resolves_link
    skip
  end

  def test_resolves_link_list
    skip
  end

  def test_resolves_metaobject_reference
    expected = { "id" => "gid://shopify/Metaobject/1" }
    assert_equal expected, resolve_fixture("metaobject_reference")
  end

  def test_resolves_metaobject_reference_list
    expected = {
      "nodes" => [
        { "id" => "gid://shopify/Metaobject/1" },
        { "id" => "gid://shopify/Metaobject/2" },
      ],
    }
    assert_equal expected, resolve_fixture("list.metaobject_reference")
  end

  def test_resolves_mixed_reference
    skip
  end

  def test_resolves_mixed_reference_list
    skip
  end

  def test_resolves_money
    expected = { "amount" => 23.99, "currencyCode" => "USD" }
    assert_equal expected, resolve_fixture("money", ["amount", "currencyCode"])
  end

  def test_resolves_money_with_aliases_and_typename
    expected = { "a" => 23.99, "c" => "USD", "__typename" => "MoneyV2" }
    assert_equal expected, resolve_fixture("money", ["a:amount", "c:currencyCode", "__typename"])
  end

  def test_resolves_multi_line_text_field
    assert_equal "hello world", resolve_fixture("multi_line_text_field")
  end

  def test_resolves_decimal
    assert_equal 23.99, resolve_fixture("number_decimal")
  end

  def test_resolves_decimal_list
    assert_equal [1.1, 2.2, 3.3], resolve_fixture("list.number_decimal")
  end

  def test_resolves_integer
    assert_equal 23, resolve_fixture("number_integer")
  end

  def test_resolves_integer_list
    assert_equal [1, 2, 3], resolve_fixture("list.number_integer")
  end

  def test_resolves_product_reference
    expected = { "id" => "gid://shopify/Product/1" }
    assert_equal expected, resolve_fixture("product_reference")
  end

  def test_resolves_product_reference_list
    expected = {
      "nodes" => [
        { "id" => "gid://shopify/Product/1" },
        { "id" => "gid://shopify/Product/2" },
      ],
    }
    assert_equal expected, resolve_fixture("list.product_reference")
  end

  def test_resolves_rating
    expected = { "max" => 5.0, "min" => 1.0, "value" => 2.0 }
    assert_equal expected, resolve_fixture("rating", ["max", "min", "value"])
  end

  def test_resolves_rating_list
    expected = [
      { "max" => 5.0, "min" => 1.0, "value" => 1.0 },
      { "max" => 5.0, "min" => 1.0, "value" => 2.0 },
    ]
    assert_equal expected, resolve_fixture("list.rating", ["max", "min", "value"])
  end

  def test_resolves_rating_with_aliases_and_typename
    expected = { "m" => 5.0, "v" => 2.0, "__typename" => "RatingMetatype" }
    assert_equal expected, resolve_fixture("rating", ["m:max", "v:value", "__typename"])
  end

  def test_resolves_rich_text_field
    assert_equal metafield_values.dig("rich_text_field", "jsonValue"), resolve_fixture("rich_text_field")
  end

  def test_resolves_single_line_text_field
    assert_equal "hello world", resolve_fixture("single_line_text_field")
  end

  def test_resolves_single_line_text_field_list
    assert_equal ["alpha", "bravo"], resolve_fixture("list.single_line_text_field")
  end

  def test_resolves_url
    assert_equal "https://shopify.com", resolve_fixture("url")
  end

  def test_resolves_url_list
    assert_equal ["https://shopify.com", "https://shopify.dev"], resolve_fixture("list.url")
  end

  def test_resolves_volume
    expected = { "unit" => "FLUID_OUNCES", "value" => 23.0 }
    assert_equal expected, resolve_fixture("volume", ["unit", "value"])
  end

  def test_resolves_volume_list
    expected = [
      {
        "unit" => "FLUID_OUNCES",
        "value" => 1.0,
      },
      {
        "unit" => "FLUID_OUNCES",
        "value" => 2.0,
      }
    ]
    assert_equal expected, resolve_fixture("list.volume", ["unit", "value"])
  end

  def test_resolves_volume_with_aliases_and_typename
    expected = { "u" => "FLUID_OUNCES", "v" => 23.0, "__typename" => "VolumeMetatype" }
    assert_equal expected, resolve_fixture("volume", ["u:unit", "v:value", "__typename"])
  end

  def test_resolves_weight
    expected = { "unit" => "OUNCES", "value" => 23.0 }
    assert_equal expected, resolve_fixture("weight", ["unit", "value"])
  end

  def test_resolves_weight_list
    expected = [
      {
        "unit" => "OUNCES",
        "value" => 1.0,
      },
      {
        "unit" => "OUNCES",
        "value" => 2.0,
      }
    ]
    assert_equal expected, resolve_fixture("list.weight", ["unit", "value"])
  end

  def test_resolves_weight_with_aliases_and_typename
    expected = { "u" => "OUNCES", "v" => 23.0, "__typename" => "Weight" }
    assert_equal expected, resolve_fixture("weight", ["u:unit", "v:value", "__typename"])
  end

  private

  def resolve_fixture(metafield_type, selections = nil)
    ShopSchemaClient::MetafieldTypeResolver.resolve(
      metafield_type,
      metafield_values[metafield_type],
      selections,
    )
  end
end
