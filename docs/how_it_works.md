## How it works

### 1. Compose a reference schema

A reference schema never _executes_ a request, it simply provides introspection and validation capabilities. This schema is built by loading all metafield and metaobject definitions from the Admin API (see [sample query](./example/server.rb)), then inserting those metaobjects and metafields as native types and fields into a base version of the Shopify Admin API (see [`SchemaComposer`](./lib/schema_composer.rb)). This creates static definitions for custom elements with naming carefully scoped to avoid conflicts with the base Admin schema, for example:

```graphql
type Product {
  # full native product fields...

  extensions: ProductExtensions!
}

type ProductExtensions {
  tacoPairing: TacoMetaobject @metafield(key: "taco_pairing", type: "metaobject_reference")
}

type TacoMetaobject {
  id: ID!

  name: String @metafield(key: "name", type: "single_line_text_field")

  protein: TacoFillingMetaobject @metafield(key: "protein", type: "metaobject_reference")

  rating: RatingMetatype @metafield(key: "rating", type: "rating")

  toppings(after: String, before: String, first: Int, last: Int): TacoFillingMetaobjectConnection @metafield(key: "toppings", type: "list.metaobject_reference")
}
```

Now we now have a Shop reference schema that can introspect and validate GraphQL queries structured like this:

```graphql
query GetProduct($id: ID!){
  product(id: $id) {
    id
    title
    extensions {
      # These are all metafields...!!
      similarProduct { # product_reference
        id
        title
      }
      myTaco: tacoPairing { # metaobject_reference
        # This is a metaobject...!!
        name
        rating { # rating
          max
          value
          __typename
        }
        protein { # metaobject_reference
          name
          volume { # volume
            value
            unit
          }
        }
        toppings(first: 10) { # list.metaobject_reference
          nodes {
            name
            calories # number_integer
          }
        }
      }
    }
  }
}
```

### 2. Transform requests

In order to send the above query to the Shopify Admin API, we need to transform it into a native query structure. The [`RequestTransfomer`](./lib/request_transformer.rb) automates this:

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    title
    ___extensions_similarProduct: metafield(key: "custom.similar_product") {
      reference {
        ... on Product {
          id
          title
        }
      }
    }
    ___extensions_myTaco: metafield(key: "custom.taco_pairing") {
      reference {
        ... on Metaobject {
          name: field(key: "name") { jsonValue }
          rating: field(key: "rating") { jsonValue }
          protein: field(key: "protein") {
            reference {
              ... on Metaobject {
                name: field(key: "name") { jsonValue }
                volume: field(key: "volume") { jsonValue }
              }
            }
          }
          toppings: field(key: "toppings") {
            references(first: 10) {
              nodes {
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
}
```

While transforming the request shape, a small JSON mapping is also generated to describe transformations needed in the response data:

```json
{
  "f": {
    "product": {
      "f": {
        "extensions": {
          "fx": { "t": "custom_scope" },
          "f": {
            "similarProduct": {
              "fx": { "t": "product_reference" }
            },
            "myTaco": {
              "fx": { "t": "metaobject_reference" },
              "f": {
                "name": {
                  "fx": { "t": "single_line_text_field" }
                },
                "rating": {
                  "fx": { "t": "rating", "s": ["max", "value", "__typename"] }
                },
                "protein": {
                  "fx": { "t": "metaobject_reference" },
                  "f": {
                    "name": {
                      "fx": { "t": "single_line_text_field" }
                    },
                    "volume": {
                      "fx": { "t": "volume", "s": ["unit", "value"] }
                    }
                  }
                },
                "toppings": {
                  "fx": { "t": "list.metaobject_reference" },
                  "f": {
                    "name": {
                      "fx": { "t": "single_line_text_field" }
                    },
                    "calories": {
                      "fx": { "t": "number_integer" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

With these transformation artifacts, a query can be computed once during development, cached, and used repeatedly in production without further dependence on the shop reference schema.

### 3. Transform responses

Lastly, the [`ResponseTransfomer`](./lib/response_transformer.rb) must run on all responses, and uses the transformation mapping to shape results to match the original request. This is a quick in-memory pass that adds modest transformation overhead to cached requests:

```json
{
  "product": {
    "id": "gid://shopify/Product/6885875646486",
    "title": "Neptune Discovery Lab",
    "extensions": {
      "similarProduct": {
        "id": "gid://shopify/Product/6561850556438",
        "title": "Aquanauts Crystal Explorer Sub"
      },
      "myTaco": {
        "name": "Al Pastor",
        "rating": {
          "min": 0,
          "value": 1,
          "__typename": "RatingMetatype"
        },
        "protein": {
          "name": "Pineapple",
          "volume": {
            "value": 2,
            "unit": "OUNCES"
          }
        },
        "toppings": {
          "nodes": [
            {
              "name": "Pineapple",
              "calories": 25
            }
          ]
        }
      }
    }
  }
}
```
