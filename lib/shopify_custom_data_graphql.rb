# frozen_string_literal: true

require "graphql"
require "active_support"
require "active_support/core_ext"

module ShopifyCustomDataGraphQL
  class ValidationError < StandardError
    attr_reader :errors

    def initialize(message = nil, errors: nil)
      raise ArgumentError if (message && errors) || (message.nil? && errors.nil?)

      super(message || errors.first[:message] || errors.first["message"])
      @errors = errors || [{ "message" => message }]
    end
  end
end

require_relative "shopify_custom_data_graphql/metafield_type_resolver"
require_relative "shopify_custom_data_graphql/custom_data_catalog"
require_relative "shopify_custom_data_graphql/schema_composer"
require_relative "shopify_custom_data_graphql/admin_api_client"
require_relative "shopify_custom_data_graphql/prepared_query"
require_relative "shopify_custom_data_graphql/request_transformer"
require_relative "shopify_custom_data_graphql/response_transformer"
require_relative "shopify_custom_data_graphql/client"
require_relative "shopify_custom_data_graphql/version"
