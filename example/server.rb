# frozen_string_literal: true

require 'puma'
require 'rackup'
require 'json'
require 'graphql'
require_relative '../lib/shopify_custom_data_graphql'

class App
  def initialize
    @graphiql = File.read("#{__dir__}/graphiql.html")

    secrets = JSON.parse(
      File.exist?("#{__dir__}/secrets.json") ?
      File.read("#{__dir__}/secrets.json") :
      File.read("#{__dir__}/../secrets.json")
    )

    @mock_cache = {}
    @client = ShopifyCustomDataGraphQL::Client.new(
      shop_url: secrets["shop_url"],
      access_token: secrets["access_token"],
      api_version: "2025-01",
      file_store_path: "#{__dir__}/tmp",
      app_context_id: 20228407297,
    )

    @client.on_cache_read { |k| @mock_cache[k] }
    @client.on_cache_write { |k, v| @mock_cache[k] = v }

    puts "Loading custom data schema..."
    @client.eager_load!
    puts "Done."
  end

  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when /graphql/
      params = JSON.parse(req.body.read)
      result = @client.execute(
        query: params["query"],
        variables: params["variables"],
        operation_name: params["operationName"],
      )

      [200, {"content-type" => "application/json"}, [JSON.generate(result)]]
    when /refresh/
      reload_shop_schema
      [200, {"content-type" => "text/html"}, ["Shop schema refreshed!"]]
    else
      [200, {"content-type" => "text/html"}, [@graphiql]]
    end
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
