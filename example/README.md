# Shop client example

This is an extremely simple shop schema server. When it boots, it will load all product metafields and metaobject definitions from the target shop and build them into a schema projection. For demonstration purposes, make sure the shop you target has product metafields that include metaobject references.

## Setup

```shell
cd example
```

Then create a `secrets.json` file with the following:

```json
{
  "shop_url": "https://shop1.myshopify.com",
  "access_token": "my_access_token"
}
```

Then from within the `example` directory, run it:

```shell
bundle install
bundle exec ruby server.rb
```

Then visit the service at [`http://localhost:3000`](http://localhost:3000). At any time, you can make a request to `/refresh` to have the server's schema projection reload with the shop's latest metafields and metaobjects.

## What am I looking at?

Start by clicking open the `Docs` panel and review the introspection. Note that `Product` has a new `extensions` field of type `ProductExtensions`. Look at that type, and you'll see your metafields projected as native schema fields. Referenced metaobjects will be projected as native object types. That means you can write selections like this:

```graphql
{
  product(id: "gid://shopify/Product/6885875646486") {
    id
    title
    extensions {
      flexRating
      tacoPairing {
        name
        protein {
          name
          volume {
            unit
            value
          }
        }
        toppings(first: 10) {
          nodes {
            name
            volume {
              value
            }
          }
        }
      }
    }
  }
}
```

## How does it work?

1. Server loads metafield and metaobject definitions via the Admin API.
2. Custom fields and types are composed into a base version of the Admin schema.
3. Introspection requestions are executed against the composed shop schema.
4. Requests are first validated against the composed shop schema.
  - Invalid requests return their validation errors directly.
  - Valid requests are transformed and sent to the Admin API.
5. Results are transformed to match the shape of the original shop request.

While this is all being done here with a small Ruby server, this same process could work directly in a web browser in development mode. In production, we'd want to cache the transformed queries and use them directly to eliminate pre-processing. Requests always need post-processing.
