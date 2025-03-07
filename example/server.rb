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

    catalog = duration("Loading custom data catalog") do
      ShopSchemaClient::SchemaCatalog.fetch(@client, app: true)
    end

    base_schema = duration("Loading base admin schema") do
      file_path = "#{__dir__}/shopify_admin_#{@client.api_version.underscore}_app#{@client.api_client_id}.graphql"
      begin
        GraphQL::Schema.from_definition(File.read(file_path))
      rescue Errno::ENOENT
        puts "-> no cached admin schema, fetching introspection..."
        File.write(file_path, @client.schema.to_definition)
        @client.schema
      end
    end

    @shop_schema = duration("Composing reference schema") do
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
    puts "#{action}..."
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    puts "-> done in #{duration}s"
    result
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
