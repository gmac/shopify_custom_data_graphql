# frozen_string_literal: true

require "test_helper"

describe "First Test" do
  QUERY = %|query GetProduct($id: ID!){
    node(id: $id) {... on Product {
      id
      title
      extensions {
        __typename
        ...Sfoo
        ...on ProductExtensions {
          flexRating
        }
        similarProduct {
          id
          title
        }
        myTaco: tacoPairing {
          __typename
          name
          rating {
            min
            value
            __typename
          }
          protein {
            name
            volume {
              sfoo:value
              unit
              __typename
            }
          }
          toppings(first: 10) {
            nodes {
              name
              volume {
                ...Volume
              }
            }
          }
        }
      }
    }
  }}
  fragment Sfoo on ProductExtensions { flexRating }
  fragment Volume on VolumeMetatype { value unit }
  |

  def test_up_and_running
    schema = load_admin_schema
    catalog = load_metaschema_catalog
    shop_schema = ShopSchemaClient::ShopSchemaComposer.new(schema, catalog).perform

    document = GraphQL.parse(QUERY)
    query = GraphQL::Query.new(shop_schema, document: document, context: {})
    errors = shop_schema.static_validator.validate(query)[:errors]
    puts "valid: #{errors.empty?}"
    puts errors.map(&:message) if errors.any?

    # binding.pry
    xform_result = ShopSchemaClient::RequestTransformer.new(query).perform
    # puts xform_result.query
    pp xform_result.transform_map.as_json
    #puts JSON.pretty_generate(xform_result.transform_map.as_json)

    http_result = JSON.parse(File.read("#{__dir__}/../fixtures/response.json"))
    pp ShopSchemaClient::ResponseTransformer.new(http_result, xform_result.transforms).perform
    assert true
  end
end
