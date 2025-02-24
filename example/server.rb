# frozen_string_literal: true

require 'puma'
require 'rackup'
require "net/http"
require "uri"
require 'json'
require 'graphql'
require_relative '../lib/shop_schema_client'

SCHEMA_QUERY = %|
  query {
    metaobjectDefinitions(first: 250) {
      nodes {
        id
        description
        name
        type
        fieldDefinitions {
          key
          description
          required
          type { name }
          validations {
            name
            value
          }
        }
      }
    }
    product_metafields: metafieldDefinitions(first: 250, ownerType: PRODUCT) {
      nodes { ...MetafieldAttrs }
    }
    # product_variant_metafields: metafieldDefinitions(first: 250, ownerType: PRODUCTVARIANT) {
    #   nodes { ...MetafieldAttrs }
    # }
    collection_metafields: metafieldDefinitions(first: 250, ownerType: COLLECTION) {
      nodes { ...MetafieldAttrs }
    }
  }
  fragment MetafieldAttrs on MetafieldDefinition {
    id
    key
    description
    type { name }
    validations {
      name
      value
    }
    ownerType
  }
|

class App
  def initialize
    @graphiql = File.read("#{__dir__}/graphiql.html")
    @secrets = JSON.parse(File.read("#{__dir__}/secrets.json"))
    reload_shop_schema
  end

  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when /graphql/
      params = JSON.parse(req.body.read)
      query = GraphQL::Query.new(
        @shop_schema,
        query: params["query"],
        variables: params["variables"],
        operation_name: params["operationName"],
      )

      result = if query.selected_operation.name == "IntrospectionQuery"
        query.result.to_h
      else
        serve_shop_request(query)
      end

      [200, {"content-type" => "application/json"}, [JSON.generate(result)]]
    when /refresh/
      reload_shop_schema
      [200, {"content-type" => "text/html"}, ["Shop schema refreshed!"]]
    else
      [200, {"content-type" => "text/html"}, [@graphiql]]
    end
  end

  def shop_request(query, variables = nil)
    response = ::Net::HTTP.post(
      URI("#{@secrets["shop_url"]}/admin/api/2025-01/graphql"),
      JSON.generate({
        "query" => query,
        "variables" => variables,
      }),
      {
        "X-Shopify-Access-Token" => @secrets["access_token"],
        "Content-Type" => "application/json",
        "Accept" => "application/json",
      },
    )

    JSON.parse(response.body)
  end

  def reload_shop_schema
    base_sdl = File.read("#{__dir__}/../test/fixtures/admin_2025_01_public.graphql")
    base_schema = GraphQL::Schema.from_definition(base_sdl)

    # load in metaobject definitions and product metafields...
    result = shop_request(SCHEMA_QUERY)
    metaobjects = result.dig("data", "metaobjectDefinitions", "nodes").map do |metaobject_def|
      ShopSchemaClient::SchemaComposer::MetaobjectDefinition.from_graphql(metaobject_def)
    end

    metafields = []
    result["data"].each do |key, conn_data|
      next unless key.end_with?("_metafields")

      conn_data["nodes"].each do |metafield_def|
        metafields << ShopSchemaClient::SchemaComposer::MetafieldDefinition.from_graphql(metafield_def)
      end
    end

    catalog = ShopSchemaClient::SchemaComposer::MetatypesCatalog.new
    catalog.add_metaobjects(metaobjects)
    catalog.add_metafields(metafields)

    # build them into a composed shop schema...
    @shop_schema = ShopSchemaClient::SchemaComposer.new(base_schema, catalog).perform
    puts "Shop schema loaded!"
  end

  def serve_shop_request(query)
    # statically validate using the shop schema, return any errors...
    errors = @shop_schema.static_validator.validate(query)[:errors]
    if errors.any?
      { errors: errors.map(&:to_h) }
    else
      # valid request shape; transform it and send it...
      shop_query = ShopSchemaClient::RequestTransformer.new(query).perform
      shop_query.perform do |query_string|
        puts query_string
        shop_request(query_string, query.variables.to_h)
      end
    end
  rescue ShopSchemaClient::ValidationError => e
    { errors: [{ message: e.message }] }
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
