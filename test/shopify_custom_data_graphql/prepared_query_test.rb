# frozen_string_literal: true

require "test_helper"

describe "PreparedQuery" do
  def setup
    @query = "{ product { id extensions { toggle } } }"
    @transformed_query = %|{ product { id ___extensions_boolean: metafield(key: "toggle") { jsonValue } } }|
    @transforms = { "f" => { "extensions" => { "fx" => { "t" => "custom_scope" } } } }
  end

  def test_builds_from_and_serializes_to_json
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new(
      query: @query,
      transforms: @transforms
    )

    expected = {
      "query" => @query,
      "transforms" => @transforms,
    }

    assert_equal expected, prepared_query.as_json
  end

  def test_omits_query_when_transforms_are_empty
    prepared_query = ShopifyCustomDataGraphQL::PreparedQuery.new(
      query: @query,
      transforms: {}
    )

    expected = {}

    assert_equal expected, prepared_query.as_json
  end

  def test_raises_for_no_query_to_execute
    assert_raises(ShopifyCustomDataGraphQL::PreparedQuery::NoQueryError) do
      ShopifyCustomDataGraphQL::PreparedQuery.new.perform
    end
  end
end
