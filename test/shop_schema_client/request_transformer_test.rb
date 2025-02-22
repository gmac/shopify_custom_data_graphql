# frozen_string_literal: true

require "test_helper"

describe "RequestTransformer" do
  def test_transforms_extensions_scalar_fields
    result = transform_request(%|query {
      product(id: "1") {
        title
        extensions {
          boolean
          color
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        title
        __ex_boolean: metafield(key: "custom.boolean") { value }
        __ex_color: metafield(key: "custom.color") { value }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_extensions_value_object_fields
    result = transform_request(%|query {
      product(id: "1") {
        title
        extensions {
          dimension { unit value }
          rating { max min value }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        title
        __ex_dimension: metafield(key: "custom.dimension") { value }
        __ex_rating: metafield(key: "custom.rating") { value }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_extensions_reference_fields
    result = transform_request(%|query {
      product(id: "1") {
        title
        extensions {
          fileReference { id alt }
          productReference { id title }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        title
        __ex_fileReference: metafield(key: "custom.file_reference") {
          reference { ... on File { id alt } }
        }
        __ex_productReference: metafield(key: "custom.product_reference") {
          reference { ... on Product { id title } }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_extensions_reference_list_fields
    result = transform_request(%|query {
      product(id: "1") {
        title
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

    expected = %|query {
      product(id: "1") {
        title
        __ex_fileReferenceList: metafield(key: "custom.file_reference_list") {
          references(first: 10, after: "r2d2") {
            nodes { ... on File { id alt } }
          }
        }
        __ex_productReferenceList: metafield(key: "custom.product_reference_list") {
          references(last: 10, before: "c3p0") {
            edges { node { ... on Product { id title } } }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_extensions_typename
    result = transform_request(%|query {
      product(id: "1") {
        __typename
        extensions { __typename }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __typename
        __ex___typename: __typename
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_nested_extension_fields
    result = transform_request(%|query {
      product(id: "1") {
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

    expected = %|query {
      product(id: "1") {
        title
        __ex_productReference: metafield(key: "custom.product_reference") {
          reference {
            ... on Product {
              title
              __ex_boolean: metafield(key: "custom.boolean") { value }
              __ex_color: metafield(key: "custom.color") { value }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_extension_fields_with_aliases
    result = transform_request(%|query {
      product(id: "1") {
        title
        extensions {
          myBoolean: boolean
          myColor: color
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        title
        __ex_myBoolean: metafield(key: "custom.boolean") { value }
        __ex_myColor: metafield(key: "custom.color") { value }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_restricts_reserved_extensions_alias_prefix
    error = assert_raises(ShopSchemaClient::ValidationError) do
      transform_request(%|query {
        product(id: "1") { __ex_sfoo: title }
      }|)
    end

    assert_equal "Field aliases starting with `__ex_` are reserved for system use.", error.message
  end

  def test_restricts_reserved_typehint_alias
    error = assert_raises(ShopSchemaClient::ValidationError) do
      transform_request(%|query {
        product(id: "1") { __typehint: title }
      }|)
    end

    assert_equal "Field alias `__typehint` is reserved for system use.", error.message
  end


  def test_transforms_metaobject_scalar_fields
    result = transform_request(%|query {
      product(id: "1") {
        extensions {
          widget {
            boolean
            color
          }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              boolean: field(key: "boolean") { value }
              color: field(key: "color") { value }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_metaobject_value_object_fields
    result = transform_request(%|query {
      product(id: "1") {
        extensions {
          widget {
            dimension { unit value }
            rating { max min value }
          }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              dimension: field(key: "dimension") { value }
              rating: field(key: "rating") { value }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_metaobject_reference_fields
    result = transform_request(%|query {
      product(id: "1") {
        extensions {
          widget {
            fileReference { id alt }
            productReference { id title }
          }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              fileReference: field(key: "file_reference") {
                reference { ... on File { id alt } }
              }
              productReference: field(key: "product_reference") {
                reference { ... on Product { id title } }
              }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_metaobject_reference_list_fields
    result = transform_request(%|query {
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

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              fileReferenceList: field(key: "file_reference_list") {
                references(first: 10, after: "r2d2") {
                  nodes { ... on File { id alt } }
                }
              }
              productReferenceList: field(key: "product_reference_list") {
                references(last: 10, before: "c3p0") {
                  edges { node { ... on Product { id title } } }
                }
              }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_metaobject_typename
    result = transform_request(%|query {
      product(id: "1") {
        extensions {
          widget { __typename }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference { ... on Metaobject { __typename: type } }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_nested_metaobject_fields
    result = transform_request(%|query {
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

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              widget: field(key: "widget") {
                reference {
                  ... on Metaobject {
                    boolean: field(key: "boolean") { value }
                    color: field(key: "color") { value }
                  }
                }
              }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  def test_transforms_metaobject_fields_with_aliases
    result = transform_request(%|query {
      product(id: "1") {
        extensions {
          widget {
            myBoolean: boolean
            myColor: color
          }
        }
      }
    }|)

    expected = %|query {
      product(id: "1") {
        __ex_widget: metafield(key: "custom.widget") {
          reference {
            ... on Metaobject {
              myBoolean: field(key: "boolean") { value }
              myColor: field(key: "color") { value }
            }
          }
        }
      }
    }|

    assert_equal expected.squish, result.as_json["query"].squish
  end

  private

  def transform_request(document, variables: {}, operation_name: nil, schema: nil)
    query = GraphQL::Query.new(
      schema || shop_schema,
      query: document,
      variables: variables,
      operation_name: operation_name,
    )
    ShopSchemaClient::RequestTransformer.new(query).perform
  end
end
