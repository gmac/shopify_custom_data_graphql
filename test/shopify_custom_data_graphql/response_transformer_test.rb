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

    assert_equal expected, result.to_h.dig("data")
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

    assert_equal expected, result.to_h.dig("data")
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
            "alt" => "Echoes of Twilight Silence",
          },
          "productReference" => {
            "id" => "gid://shopify/Product/6561850556438",
            "title" => "Aquanauts Crystal Explorer Sub",
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end


  def test_transforms_extensions_reference_list_fields
    result = fetch("transforms_extensions_reference_list_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        id
        extensions {
          fileReferenceList(first: 10, after: "r2d2") {
            nodes { id alt }
          }
          productReferenceList(last: 10, before: "c3p0") {
            edges { node { id title } }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "id" => PRODUCT_ID,
        "extensions" => {
          "fileReferenceList" => {
            "nodes" => [{
              "id" => "gid://shopify/MediaImage/20354823356438",
              "alt" => "A scenic landscape",
            }],
          },
          "productReferenceList" => {
            "edges" => [{
              "node" => {
                "id" => "gid://shopify/Product/6561850556438",
                "title" => "Aquanauts Crystal Explorer Sub",
              },
            }],
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_extensions_typename
    result = fetch("transforms_extensions_typename", %|query {
      product(id: "#{PRODUCT_ID}") {
        __typename
        extensions { __typename }
      }
    }|)

    expected = {
      "product" => {
        "__typename" => "Product",
        "extensions" => { "__typename" => "ProductExtensions" },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_nested_extension_fields
    result = fetch("transforms_nested_extension_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        title
        extensions {
          productReference {
            title
            extensions {
              boolean
              color
            }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "title" => "Neptune Discovery Base",
        "extensions" => {
          "productReference" => {
            "title" => "Crystal Explorer Sub",
            "extensions" => {
              "boolean" => true,
              "color" => "#0000FF",
            }
          }
        }
      }
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_extensions_fields_with_aliases
    result = fetch("transforms_extensions_fields_with_aliases", %|query {
      product(id: "#{PRODUCT_ID}") {
        extensions1: extensions {
          myBoolean: boolean
          myTypename: __typename
        }
        extensions2: extensions {
          myColor: color
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions1" => {
          "myBoolean" => true,
          "myTypename" => "ProductExtensions",
        },
        "extensions2" => {
          "myColor" => "#0000FF",
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_scalar_fields
    result = fetch("transforms_metaobject_scalar_fields", %|query {
      product(id: "#{PRODUCT_ID}") {
        extensions {
          widget {
            boolean
            color
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "boolean" => true,
            "color" => "#0000FF",
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_value_object_fields
    result = fetch("transforms_metaobject_value_object_fields", %|query {
      product(id: "1") {
        extensions {
          widget {
            dimension { unit value }
            rating { maximum: max value }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "dimension" => {
              "unit" => "INCHES",
              "value" => 23.0
            },
            "rating" => {
              "maximum" => 5.0,
              "value" => 5.0
            }
          }
        }
      }
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_reference_fields
    result = fetch("transforms_metaobject_reference_fields", %|query {
      product(id: "1") {
        extensions {
          widget {
            fileReference { id alt }
            productReference { id title }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "fileReference" => {
              "id" => "gid://shopify/File/1",
              "alt" => "A Thousand Dreams Encapsulated",
            },
            "productReference" => {
              "id" => "gid://shopify/Product/2",
              "title" => "Whispering Willows Light",
            },
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_reference_list_fields
    result = fetch("transforms_metaobject_reference_list_fields", %|query {
      product(id: "1") {
        extensions {
          widget {
            fileReferenceList(first: 10, after: "r2d2") {
              nodes { id alt }
            }
            productReferenceList(last: 10, before: "c3p0") {
              edges { node { id title } }
            }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "fileReferenceList" => {
              "nodes" => [
                {
                  "id" => "gid://shopify/File/101",
                  "alt" => "Whispers of the Moonlit Sea",
                },
                {
                  "id" => "gid://shopify/File/102",
                  "alt" => "Ethereal Dance of the Aurora",
                }
              ]
            },
            "productReferenceList" => {
              "edges" => [
                {
                  "node" => {
                    "id" => "gid://shopify/Product/201",
                    "title" => "Echoes of Twilight Silence",
                  }
                },
                {
                  "node" => {
                    "id" => "gid://shopify/Product/202",
                    "title" => "Serenade of the Night's End",
                  }
                }
              ]
            }
          }
        }
      }
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_typename
    result = fetch("transforms_metaobject_typename", %|query {
      product(id: "1") {
        extensions {
          widget { __typename }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "__typename" => "WidgetMetaobject",
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_nested_metaobject_fields
    result = fetch("transforms_nested_metaobject_fields", %|query {
      product(id: "1") {
        extensions {
          widget {
            widget {
              boolean
              color
            }
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "widget" => {
              "boolean" => true,
              "color" => "#4A90E2",
            },
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_fields_with_aliases
    result = fetch("transforms_metaobject_fields_with_aliases", %|query {
      product(id: "1") {
        extensions {
          widget {
            myBoolean: boolean
            myColor: color
            myTypename: __typename
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "myBoolean" => true,
            "myColor" => "#7A3B6C",
            "myTypename" => "WidgetMetaobject",
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_only_custom_metaobject_fields
    result = fetch("transforms_only_custom_metaobject_fields", %|query {
      product(id: "1") {
        extensions {
          widget {
            id
            handle
            boolean
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "widget" => {
            "id" => "gid://shopify/Metaobject/1",
            "handle" => "celestial-harmony",
            "boolean" => false,
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_coalesces_value_object_selections
    result = fetch("coalesces_value_object_selections", %|query {
      product(id: "1") {
        extensions {
          rating {
            max
          }
          rating {
            min
            value
          }
        }
      }
    }|)

    expected = {
      "product" => {
        "extensions" => {
          "rating" => {
            "max" => 5,
            "min" => 0,
            "value" => 4.5,
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_extracts_value_object_selection_fragents
    result = fetch("extracts_value_object_selection_fragents", %|query {
      product(id: "1") {
        extensions {
          rating1: rating {
            ... on RatingMetatype { max }
            ... RatingAttrs
            ... { value }
          }
          rating2: rating {
            ... {
              max
              ... on RatingMetatype {
                ... RatingAttrs
                value
              }
            }
          }
        }
      }
    }
    fragment RatingAttrs on RatingMetatype { min }
    |)

    expected = {
      "product" => {
        "extensions" => {
          "rating1" => {
            "max" => 5,
            "min" => 0,
            "value" => 4.5,
          },
          "rating2" => {
            "max" => 5,
            "min" => 0,
            "value" => 4.5,
          },
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_fragments_on_custom_scope
    result = fetch("transforms_fragments_on_custom_scope", %|query {
      product(id: "1") {
        extensions {
          ... on ProductExtensions { boolean }
          ...ProductExtensionsAttrs
        }
      }
    }
    fragment ProductExtensionsAttrs on ProductExtensions { color }
    |)

    expected = {
      "product" => {
        "extensions" => {
          "boolean" => true,
          "color" => "#F39C12",
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_inline_fragments_with_type_condition
    result = fetch("inline_fragments_with_type_condition", %|query {
      node(id: "1") {
        ... { id }
        ... on Product {
          title
          productExt: extensions { boolean }
        }
        ... on ProductVariant {
          title
          variantExt: extensions { test }
        }
      }
    }|)

    expected = {
      "node" => {
        "id" => "gid://shopify/Product/1",
        "title" => "Ethereal Dreams T-Shirt",
        "productExt" => {
          "boolean" => true,
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_fragment_spreads_with_type_condition
    result = fetch("fragment_spreads_with_type_condition", %|query {
      node(id: "1") {
        id
        ...ProductAttrs
        ...VariantAttrs
      }
    }
    fragment ProductAttrs on Product {
      title
      productExt: extensions { boolean }
    }
    fragment VariantAttrs on ProductVariant {
      title
      variantExt: extensions { test }
    }|)

    expected = {
      "node" => {
        "id" => "gid://shopify/Product/1",
        "title" => "Ethereal Dreams T-Shirt",
        "productExt" => {
          "boolean" => true,
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
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

    assert_equal expected, result.to_h.dig("data")
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

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_root_query_extensions
    result = fetch("root_query_extensions", %|query {
      extensions {
        widgetMetaobjects(first: 10) {
          nodes {
            id
            boolean
            rating {
              max
              value
            }
          }
        }
      }
    }|)

    expected = {
      "extensions" => {
        "widgetMetaobjects" => {
          "nodes" => [{
            "id" => "gid://shopify/Metaobject/1",
            "boolean" => true,
            "rating" => {
              "max" => 5.0,
              "value" => 5.0,
            },
          }],
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_metaobject_system_extensions
    result = fetch("metaobject_system_extensions", %|query {
      extensions {
        widgetMetaobjects(first: 10) {
          nodes {
            id
            handle
            system {
              createdByStaff { id }
              updatedAt
            }
            boolean
          }
        }
      }
    }|)

    expected = {
      "extensions" => {
        "widgetMetaobjects" => {
          "nodes" => [{
            "id" => "gid://shopify/Metaobject/1",
            "handle" => "gourmet-gadgetry",
            "system" => {
              "createdByStaff" => {
                "id" => "gid://shopify/User/1",
              },
              "updatedAt" => "2025-03-20T02:00:00Z",
            },
            "boolean" => true,
          }],
        },
      },
    }

    assert_equal expected, result.to_h.dig("data")
  end

  def test_transforms_errors_with_object_paths
    result = fetch("errors_with_object_path", %|query {
      product(id: "#{PRODUCT_ID}") {
        extensions {
          widget {
            system {
              createdByStaff { name }
            }
          }
        }
      }
    }|, expect_valid_response: false)

    expected_errors = [{
      "message" => "Access denied for createdByStaff field.",
      "path" => ["product", "extensions", "widget", "system", "createdByStaff"],
      "extensions" => { "code" => "ACCESS_DENIED" },
    }]

    assert_equal expected_errors, result.to_h.dig("errors")
  end

  def test_transforms_errors_with_list_paths
    result = fetch("errors_with_list_path", %|query {
      products(first: 1) {
        nodes {
          extensions {
            widget {
              system {
                createdByStaff { name }
              }
            }
          }
        }
      }
    }|, expect_valid_response: false)

    expected_errors = [{
      "message" => "Access denied for createdByStaff field.",
      "path" => ["products", "nodes", 0, "extensions", "widget", "system", "createdByStaff"],
      "extensions" => { "code" => "ACCESS_DENIED" },
    }]

    assert_equal expected_errors, result.to_h.dig("errors")
  end

  private

  SCALAR_VALIDATORS = GraphQL::ResponseValidator::SCALAR_VALIDATORS.merge({
    "JSON" => -> (value) { true }
  }).freeze

  def fetch(fixture, document, variables: {}, operation_name: nil, schema: nil, expect_valid_response: true)
    query = GraphQL::Query.new(
      schema || shop_schema,
      query: document,
      variables: variables,
      operation_name: operation_name,
    )

    errors = query.schema.static_validator.validate(query)[:errors]
    refute errors.any?, "Invalid custom data query: #{errors.first.message}" if errors.any?
    prepared_query = ShopifyCustomDataGraphQL::RequestTransformer.new(query).perform
    prepared_query.perform do |pq|
      file_path = "#{__dir__}/../fixtures/responses/#{fixture}.json"
      response = JSON.parse(File.read(file_path))

      if expect_valid_response
        # validate that the cached fixture matches the request shape
        admin_query = GraphQL::Query.new(base_schema, query: pq.query)
        fixture = GraphQL::ResponseValidator.new(admin_query, response, scalar_validators: SCALAR_VALIDATORS)
        assert fixture.valid?, "#{fixture.errors.map(&:message).join("\n")} in:\n#{pq.query}"
        fixture.prune!.to_h
      else
        response
      end
    end
  end
end
