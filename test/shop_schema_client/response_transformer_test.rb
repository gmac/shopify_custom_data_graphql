# frozen_string_literal: true

require "test_helper"

describe "ResponseTransformer" do
  PRODUCT_ID = "gid://shopify/Product/6885875646486"

  def test_transforms_extensions_scalar_fields
    result = fetch("transforms_extensions_scalar_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        id
        extensions {
          boolean
          color
        }
      }
    }|)

    expected = {
      "product" => {
        "id" => PRODUCT_ID,
        "extensions" => {
          "boolean" => true,
          "color" => "#006ba0",
        },
      },
    }

    assert_equal expected, result.dig("data")
  end

  private

  def fetch(fixture, document, variables: {}, operation_name: nil, schema: nil)
    query = GraphQL::Query.new(
      schema || shop_schema,
      query: document,
      variables: variables,
      operation_name: operation_name,
    )

    assert query.schema.static_validator.validate(query)[:errors].none?, "Invalid shop query."
    shop_query = ShopSchemaClient::RequestTransformer.new(query).perform
    shop_query.perform do |query_string|
      fetch_response(fixture, query_string)
    end
  end
end
