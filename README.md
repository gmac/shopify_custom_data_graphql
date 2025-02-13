# shop-schema-client

An experimental client for interfacing with Shopify metafields and metaobjects through a statically-typed schema projection.

## How it works

### 1. Compose schema projection

A schema projection first loads all metafield and metaobject definitions from the Admin API (see [sample query](./files/shop_metaschema.graphql)). Then it loads a base version of the Shopify Admin API (see [base schema](./files/admin_2025_01_public.graphql)), and projects metafields and metaobjects as native fields and types into that schema (see [schema projection](./files/admin_2025_01_shop.graphql#L64985-L65007)). This creates static definitions for custom elements with naming carefully scoped to avoid conflicts with the base Admin schema, for example:

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

With this done, we now have a Shop schema projection that can compose and validate GraphQL queries structured like this:

```graphql
query GetProduct($id: ID!){
  product(id: $id) {
    id
    title
    extensions {
      # These are all metafields...!!
      flexRating # number_decimal
      similarProduct { # product_reference
        id
        title
      }
      myTaco: tacoPairing { # metaobject_reference
        # This is a metaobject...!!
        name
        rating { # rating
          min
          value
          __typename
        }
        protein { # metaobject_reference
          name
          volume { # volume
            value
            unit
            __typename
          }
        }
        toppings(first: 10) { # list.metaobject_reference
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
}
```

### 2. Transform requests

In order to actually send the above query to the Shopify Admin API, we need to transform it into a native query structure. The [`RequestTransfomer`](./lib/request_transformer.rb) automates this, and the transformed query can be processed once and used repeatedly with no subsequent request overhead:

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    title
    __extensions__flexRating: metafield(key: "custom.flex_rating") {
      value
    }
    __extensions__similarProduct: metafield(key: "custom.similar_product") {
      reference {
        ... on Product {
          id
          title
        }
      }
    }
    __extensions__myTaco: metafield(key: "custom.taco_pairing") {
      reference {
        ... on Metaobject {
          name: field(key: "name") {
            value
          }
          rating: field(key: "rating") {
            value
          }
          protein: field(key: "protein") {
            reference {
              ... on Metaobject {
                name: field(key: "name") {
                  value
                }
                volume: field(key: "volume") {
                  value
                }
              }
            }
          }
          toppings: field(key: "toppings") {
            references(first: 10) {
              nodes {
                ... on Metaobject {
                  name: field(key: "name") {
                    value
                  }
                  volume: field(key: "volume") {
                    value
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

### 3. Transform responses

Lastly, we need to transform the native query response to match the projected request shape. This is handled by the [`ResponseTransfomer`](./lib/response_transformer.rb), which must run on each response. This light in-memory pass on the native response data is the _only_ overhead added to repeated requests. The transformed results match the original projected request shape:

```json
{
  "product": {
    "id": "gid://shopify/Product/6885875646486",
    "title": "Neptune Discovery Lab",
    "extensions": {
      "flexRating": 1.5,
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
            "unit": "MILLILITERS",
            "__typename": "VolumeMetatype"
          }
        },
        "toppings": {
          "nodes": [
            {
              "name": "Pineapple",
              "volume": {
                "value": 2,
                "unit": "MILLILITERS"
              }
            }
          ]
        }
      }
    }
  }
}
```

## Current support

This is a scrappy prototype. Still needs several major implementation details:

- Abstract type handling
- Selection fragment handling
- Consistent `__typename` handling
- Support for `mixed_reference` metafields
