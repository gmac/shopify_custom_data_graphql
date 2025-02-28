# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module ShopSchemaClient
  class AdminApiClient
    def initialize(shop_url:, access_token:, api_version: "2025-01")
      @shop_url = shop_url
      @access_token = access_token
      @api_version = api_version
    end

    def fetch(query, variables: nil, operation_name: nil)
      response = ::Net::HTTP.post(
        URI("#{@shop_url}/admin/api/#{@api_version}/graphql"),
        JSON.generate({
          "query" => query,
          "variables" => variables,
          "operationName" => operation_name,
        }.tap(&:compact!)),
        {
          "X-Shopify-Access-Token" => @access_token,
          "Content-Type" => "application/json",
          "Accept" => "application/json",
        },
      )

      JSON.parse(response.body)
    end
  end
end
