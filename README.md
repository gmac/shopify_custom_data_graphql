# Shopify Custom Data GraphQL

A Shopify Admin API client for interacting with a Shop or App's metafields and metaobjects using statically-typed GraphQL, similar to [Contentful APIs](https://www.contentful.com/developers/docs/references/graphql). This allows a complex custom data query such as this:

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    title
    rating: metafield(key: "custom.rating") { jsonValue }
    tacoPairing: metafield(key: "custom.taco_pairing") {
      reference {
        ... on Metaobject {
          name: field(key: "name") { jsonValue }
          protein: field(key: "protein") {
            reference {
              ... on Metaobject {
                name: field(key: "name") { jsonValue }
                calories: field(key: "calories") { jsonValue }
              }
            }
          }
        }
      }
    }
  }
}
```

To be expressed as this:

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    title
    extensions { # These are metafields...
      rating { # this is a metafield value!
        max
        value
      }
      tacoPairing { # this is a metaobject!
        name
        protein { # this is a metaobject!
          name
          calories
        }
      }
    }
  }
}
```

The client works by composing a superset of the base Shopify Admin API with a Shop or App's custom data modeling inserted. This reference schema provides introspection (for live documentation), request validation, and the basis for transforming custom data queries into native Admin API requests. With layers of caching options, these transformed queries can be used in both development and production with minimal overhead.

## Getting started

Add to your Gemfile:

```ruby
gem "shopify_custom_data_graphql"
```

Run bundle install, then require unless running an autoloading framework (Rails, etc):

```ruby
require "shopify_custom_data_graphql"
```

Setup a client:

```ruby
def launch
  # Build a client...
  @client = ShopifyCustomDataGraphQL::Client.new(
    shop_url: ENV["shop_url"], # << "https://myshop.myshopify.com"
    access_token: ENV["access_token"],
    api_version: "2025-01",
    file_store_path: Rails.root.join("db/schemas"),
  )

  # Add hooks for caching processed queries...
  @client.on_cache_read { |key| $mycache.get(key) }
  @client.on_cache_write { |key, value| $mycache.set(key, value) }

  # Eager-load schemas into the client...
  # (takes several seconds for the initial cold start, then gets faster)
  @client.eager_load!
end
```

Make requests:

```ruby
def graphql
  result = @client.execute(
    query: params["query"],
    variables: params["variables"],
    operation_name: params["operationName"],
  )
  JSON.generate(result)
end
```

## Configuration

Tktk...
