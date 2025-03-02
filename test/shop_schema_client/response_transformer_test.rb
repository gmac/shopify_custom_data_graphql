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

  def test_transforms_extensions_value_object_fields
    result = fetch("transforms_extensions_value_object_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        id
        extensions {
          dimension { unit value }
          rating { maximum: max value }
        }
      }
    }|)

    expected = {
      "product" => {
        "id" => PRODUCT_ID,
        "extensions" => {
          "dimension" => {
            "unit" => "INCHES",
            "value" => 24.0,
          },
          "rating" => {
            "maximum" => 5.0,
            "value" => 5.0,
          },
        },
      },
    }

    assert_equal expected, result.dig("data")
  end

  def test_transforms_extensions_reference_fields
    result = fetch("transforms_extensions_reference_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        id
        extensions {
          fileReference { id alt }
          productReference { id title }
        }
      }
    }|)

    expected = {
      "product" => {
        "id" => PRODUCT_ID,
        "extensions" => {
          "fileReference" => {
            "id" => "gid://shopify/MediaImage/20354823356438",
            "alt" => "",
          },
          "productReference" => {
            "id" => "gid://shopify/Product/6561850556438",
            "title" => "Aquanauts Crystal Explorer Sub",
          },
        },
      },
    }

    assert_equal expected, result.dig("data")
  end

  def test_transforms_mixed_reference_with_matching_type_selection
    result = fetch("mixed_reference_returning_taco", %|query {
      product(id: "1") {
        extensions {
          mixedReference {
            ... on TacoMetaobject { id name }
            ... on TacoFillingMetaobject { id calories }
            __typename
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "mixedReference" => {
            "id" => "gid://shopify/Metaobject/1",
            "name" => "Al Pastor",
            "__typename" => "TacoMetaobject",
          },
        },
      },
    }

    assert_equal expected, result.dig("data")
  end

  def test_transforms_mixed_reference_without_matching_type_selection
    result = fetch("mixed_reference_returning_taco", %|query {
      product(id: "1") {
        extensions {
          mixedReference {
            ... on TacoFillingMetaobject { id calories }
            __typename
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "mixedReference" => {
            "__typename" => "TacoMetaobject",
          },
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
