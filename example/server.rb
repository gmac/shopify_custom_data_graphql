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
    productFields: metafieldDefinitions(first: 250, ownerType: PRODUCT) {
      nodes {
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
    }
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
      ShopSchemaClient::ShopSchemaComposer::MetaobjectDefinition.from_graphql(metaobject_def)
    end

    metafields = result.dig("data", "productFields", "nodes").map do |metafield_def|
      ShopSchemaClient::ShopSchemaComposer::MetafieldDefinition.from_graphql(metafield_def)
    end

    catalog = ShopSchemaClient::ShopSchemaComposer::MetaschemaCatalog.new
    catalog.add_metaobjects(metaobjects)
    catalog.add_metafields(metafields)
    catalog

    # build them into a composed shop schema...
    @shop_schema = ShopSchemaClient::ShopSchemaComposer.new(base_schema, catalog).perform
    puts "Shop schema loaded!"
  end

  def serve_shop_request(query)
    # statically validate using the shop schema, return any errors...
    errors = @shop_schema.static_validator.validate(query)[:errors]
    if errors.any?
      { errors: errors.map(&:to_h) }
    else
      # valid request shape; transform it and send it...
      xform_document = ShopSchemaClient::RequestTransformer.new(query).perform
      xform_query = GraphQL::Language::Printer.new.print(xform_document)
      puts xform_query

      result = shop_request(xform_query, query.variables.to_h)
      if result["data"]
        result["data"] = ShopSchemaClient::ResponseTransformer.new(@shop_schema, query.document).perform(result["data"])
      end
      result
    end
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
