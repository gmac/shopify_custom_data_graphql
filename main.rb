require "json"
require "graphql"
require "pry"
require_relative "./lib/shop_schema_composer"
require_relative "./lib/request_transformer"

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
        rating
        protein {
          name
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

# Load admin schema and shop metafield/metaobject definitions...
admin_schema = GraphQL::Schema.from_definition(File.read("#{__dir__}/files/admin_2025_01_public.graphql"))
meta_types = JSON.parse(File.read("#{__dir__}/files/shop_metaschema.json"))

# Compose metaschema into the admin schema
shop_schema = ShopSchemaComposer.new(meta_types, admin_schema).perform
File.write("#{__dir__}/files/admin_2025_01_shop.graphql", shop_schema.to_definition)

# Valudate the projected query against the composed shop schema
query = GraphQL::Query.new(shop_schema, query: QUERY, context: {})
puts "valid: #{shop_schema.static_validator.validate(query)[:errors].empty?}"

# Transform the query into a basic admin schema query
transformed_query = RequestTransformer.new(shop_schema).perform(QUERY)

puts "done."
