# frozen_string_literal: true

require "test_helper"

describe "First Test" do
  QUERY = %|query GetProduct($id: ID!){
    product(id: $id) {
      id
      title
      extensions {
        flexRating
        similarProduct {
          id
          title
        }
        myTaco: tacoPairing {
          name
          rating {
            min
            value
            __typename
          }
          protein {
            name
            volume {
              value
              unit
              __typename
            }
          }
          toppings(first: 10) {
            nodes {
              name
              volume {
                value
                unit
              }
            }
          }
        }
      }
    }
  }|

  def test_up_and_running
    schema = load_admin_schema
    catalog = load_metaschema_catalog
    shop_schema = ShopSchemaClient::ShopSchemaComposer.new(schema, catalog).perform

    document = GraphQL.parse(QUERY)
    query = GraphQL::Query.new(shop_schema, document: document, context: {})
    puts "valid: #{shop_schema.static_validator.validate(query)[:errors].empty?}"

    document2 = ShopSchemaClient::RequestTransformer.new(shop_schema, document).perform
    puts GraphQL::Language::Printer.new.print(document2)

    response = JSON.parse(File.read("#{__dir__}/../fixtures/response.json"))
    pp ShopSchemaClient::ResponseTransformer.new(shop_schema, document).perform(response["data"])
    assert true
  end
end
