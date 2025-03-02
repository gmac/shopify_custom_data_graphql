# frozen_string_literal: true

module ShopSchemaClient
  class SchemaCatalog
    OWNER_ENUMS = [
      "API_PERMISSION",
      "ARTICLE",
      "BLOG",
      "CARTTRANSFORM",
      "COLLECTION",
      "COMPANY",
      "COMPANY_LOCATION",
      "CUSTOMER",
      "DELIVERY_CUSTOMIZATION",
      "DISCOUNT",
      "DRAFTORDER",
      "FULFILLMENT_CONSTRAINT_RULE",
      "GIFT_CARD_TRANSACTION",
      "LOCATION",
      "MARKET",
      "MEDIA_IMAGE",
      "ORDER",
      "ORDER_ROUTING_LOCATION_RULE",
      "PAGE",
      "PAYMENT_CUSTOMIZATION",
      "PRODUCT",
      "PRODUCTVARIANT",
      "SELLING_PLAN",
      "SHOP",
      "VALIDATION",
    ].freeze

    PROBE_SCHEMA_CONTENT_QUERY = %|
      query ProbeSchemaContent {
        app { id }
        #{
          OWNER_ENUMS.map do
            %|
              #{_1}: metafieldDefinitions(first: 1, ownerType: #{_1}) {
                nodes { ...MetafieldAttrs }
                pageInfo {
                  endCursor
                  hasNextPage
                }
              }
            |
          end.join("\n")
        }
        metaobjects: metaobjectDefinitions(first: 250) {
          nodes { ...MetaobjectAttrs }
          pageInfo {
            endCursor
            hasNextPage
          }
        }
      }
      #{METAFIELD_GRAPHQL_ATTRS}
      #{METAOBJECT_GRAPHQL_ATTRS}
    |

    METAFIELD_DEFINITIONS_QUERY = %|
      query MetafieldDefs($after: String, $query: String, $owner_type: MetafieldOwnerType!) {
        app { id }
        results: metafieldDefinitions(first: 250, after: $after, query: $query, ownerType: $owner_type) {
          nodes { ...MetafieldAttrs }
          pageInfo {
            endCursor
            hasNextPage
          }
        }
      }
      #{METAFIELD_GRAPHQL_ATTRS}|

    METAOBJECT_DEFINITIONS_QUERY = %|
      query MetaobjectDefs($after: String) {
        app { id }
        results: metaobjectDefinitions(first: 250, after: $after) {
          nodes { ...MetaobjectAttrs }
          pageInfo {
            endCursor
            hasNextPage
          }
        }
      }
      #{METAOBJECT_GRAPHQL_ATTRS}|

    class << self
      def load(
        client,
        app: false,
        base_namespaces: ["custom"],
        scoped_namespaces: ["my_fields"],
        owner_types: OWNER_ENUMS
      )
        result = client.fetch(PROBE_SCHEMA_CONTENT_QUERY)
        app_id = result.dig("data", "app", "id")
        throttle_available = result.dig("extensions", "cost", "throttleStatus", "currentlyAvailable")

        catalog = SchemaCatalog.new(
          app_id: app ? app_id.split("/").pop.to_i : nil,
          base_namespaces: base_namespaces,
          scoped_namespaces: scoped_namespaces,
        )

        owner_types.each do |owner_type|
          metafields_data = result.dig("data", owner_type)
          metafields_data.dig("nodes").each { catalog.add_metafield(_1) }

          if metafields_data.dig("pageInfo", "hasNextPage")
            throttle_available = paginated_fetch(
              client,
              METAFIELD_DEFINITIONS_QUERY,
              { owner_type: owner_type },
              next_cursor: metafields_data.dig("pageInfo", "endCursor"),
              throttle_available: throttle_available,
              request_cost: 35,
            ) do |nodes|
              nodes.each { catalog.add_metafield(_1) }
            end
          end
        end

        metaobjects_data = result.dig("data", "metaobjects")
        metaobjects_data.dig("nodes").each { catalog.add_metaobject(_1) }

        if metaobjects_data.dig("pageInfo", "hasNextPage")
          paginated_fetch(
            client,
            METAOBJECT_DEFINITIONS_QUERY,
            next_cursor: metaobjects_data.dig("pageInfo", "endCursor"),
            throttle_available: throttle_available,
            request_cost: 50,
          ) do |nodes|
            nodes.each { catalog.add_metaobject(_1) }
          end
        end

        catalog
      end

      private

      def paginated_fetch(client, query, variables = {}, next_cursor: nil, request_cost: 0, throttle_available: 1)
        next_page = true
        throttle_restore = 100

        while next_page
          available = throttle_available - request_cost
          sleep (available.abs.to_f / throttle_restore) + 0.05 if available < 0

          result = client.fetch(query, variables: { after: next_cursor }.merge!(variables))
          if result["errors"]
            raise result["errors"].map { _1["message"] }.join(", ")
          else
            conn = result.dig("data", "results")
            yield(conn["nodes"], result.dig("data", "app", "id").split("/").pop.to_i)
            page_info = conn.dig("pageInfo")
            next_page = page_info["hasNextPage"]
            next_cursor = page_info["endCursor"]
          end

          cost = result.dig("extensions", "cost")
          request_cost = cost["requestedQueryCost"]
          throttle_available = cost.dig("throttleStatus", "currentlyAvailable")
          throttle_restore = cost.dig("throttleStatus", "restoreRate")
        end

        throttle_available
      end
    end
  end
end
