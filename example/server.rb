# frozen_string_literal: true

require 'puma'
require 'rackup'
require 'json'
require 'graphql'
require 'rainbow'
require_relative '../lib/shopify_custom_data_graphql'

class App
  def initialize
    @graphiql = File.read("#{__dir__}/graphiql.html")

    secrets = begin
      JSON.parse(
        File.exist?("#{__dir__}/secrets.json") ?
        File.read("#{__dir__}/secrets.json") :
        File.read("#{__dir__}/../secrets.json")
      )
    rescue Errno::ENOENT
      raise "A `secrets.json` file is required, see `example/README.md`"
    end

    @mock_cache = {}
    @client = ShopifyCustomDataGraphQL::Client.new(
      shop_url: secrets["shop_url"],
      access_token: secrets["access_token"],
      api_version: "2025-01",
      file_store_path: "#{__dir__}/tmp",
    )

    @client.on_cache_read { |k| @mock_cache[k] }
    @client.on_cache_write { |k, v| @mock_cache[k] = v }

    puts Rainbow("Loading custom data schema...").cyan.bright
    @client.eager_load!
    puts Rainbow("Done.").cyan
  end

  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when /graphql/
      params = JSON.parse(req.body.read)
      result = log_result do
        @client.execute(
          query: params["query"],
          variables: params["variables"],
          operation_name: params["operationName"],
        )
      end

      [200, {"content-type" => "application/json"}, [JSON.generate(result.to_h)]]
    when /refresh/
      @client.schema(reload_custom_schema: true)
      [200, {"content-type" => "text/html"}, ["Shop schema refreshed!"]]
    else
      [200, {"content-type" => "text/html"}, [@graphiql]]
    end
  end

  def log_result
    timestamp = Time.current
    result = yield
    message = [Rainbow("[request #{timestamp.to_s}]").cyan.bright]
    stats = ["validate", "introspection", "transform_request", "proxy", "transform_response"].filter_map do |stat|
      time = result.tracer[stat]
      next unless time

      "#{Rainbow(stat).magenta}: #{(time * 100).round / 100.to_f}ms"
    end

    message << stats.join(", ")
    message << "\n#{result.query}" if result.tracer["transform_request"]
    puts message.join(" ")
    result
  end
end

Rackup::Handler.default.run(App.new, :Port => 3000)
