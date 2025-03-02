# frozen_string_literal: true

require 'puma'
require 'rackup'
require 'json'
require 'graphql'
require_relative '../lib/shop_schema_client'

class App
  def initialize
    @graphiql = File.read("#{__dir__}/graphiql.html")

    secrets = JSON.parse(
      File.exist?("#{__dir__}/secrets.json") ?
      File.read("#{__dir__}/secrets.json") :
      File.read("#{__dir__}/../secrets.json")
    )

    @client = ShopSchemaClient::AdminApiClient.new(
      shop_url: secrets["shop_url"],
      access_token: secrets["access_token"],
    )

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

  def reload_shop_schema
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base_schema = duration("Built base schema") do
      base_sdl = File.read("#{__dir__}/../test/fixtures/admin_2025_01_public.graphql")
      GraphQL::Schema.from_definition(base_sdl)
    end

    catalog = duration("Loaded catalog") do
      ShopSchemaClient::SchemaCatalog.load(@client, app: true)
    end

    @shop_schema = duration("Composed schema") do
      ShopSchemaClient::SchemaComposer.new(base_schema, catalog).perform
    end
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
        @client.fetch(query_string, variables: query.variables.to_h)
      end
    end
  rescue ShopSchemaClient::ValidationError => e
    { errors: [{ message: e.message }] }
  end

  def duration(action)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    puts "#{action} in #{duration}s"
    result
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
