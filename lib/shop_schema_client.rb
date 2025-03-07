# frozen_string_literal: true

require "graphql"
require "active_support"
require "active_support/core_ext"

module ShopSchemaClient
  class ValidationError < StandardError; end
end

require_relative "shop_schema_client/admin_api_client"
require_relative "shop_schema_client/metafield_type_resolver"
require_relative "shop_schema_client/prepared_query"
require_relative "shop_schema_client/schema_catalog"
require_relative "shop_schema_client/schema_composer"
require_relative "shop_schema_client/request_transformer"
require_relative "shop_schema_client/response_transformer"
require_relative "shop_schema_client/version"
