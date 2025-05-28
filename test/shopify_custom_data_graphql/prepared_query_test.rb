# frozen_string_literal: true

require "test_helper"

describe "PreparedQuery" do
  def setup
    @query = "{ product { id extensions { toggle } } }"
    @transformed_query = %|{ product { id ___extensions_boolean: metafield(key: "toggle") { jsonValue } } }|
    @transforms = { "f" => { "extensions" => { "fx" => { "t" => "custom_scope" } } } }
  end

  def test_builds_from_and_serializes_to_json
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new({
      "query" => @query,
      "transforms" => @transforms,
    })

    expected = {
      "query" => @query,
      "transforms" => @transforms,
    }

    assert_equal expected, prepared_query.as_json
  end

  def test_omits_query_when_transforms_are_empty
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new({
      "query" => @query,
      "transforms" => {},
    })

    expected = {}

    assert_equal expected, prepared_query.as_json
  end

  def test_performs_transformed_query_when_available
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new({
      "query" => @transformed_query,
      "transforms" => @transforms,
    })

    prepared_query.perform(source_query: @query) do |query|
      assert_equal @transformed_query, query
      { "product" => { "id" => "1", "___extensions_boolean" => { "jsonValue" => true } } }
    end
  end

  def test_performs_source_query_when_not_transformed
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new({})

    prepared_query.perform(source_query: @query) do |query|
      assert_equal @query, query
      { "product" => { "id" => "1" } }
    end
  end

  def test_raises_for_empty_prepared_query_with_source_query
    assert_raises(ArgumentError) do
      ShopifyCustomDataGraphQL::PreparedQuery.new({}).perform(source_query: nil)
    end
  end
end
