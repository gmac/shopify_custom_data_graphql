# frozen_string_literal: true

require "graphql"
require "active_support"
require "active_support/core_ext"

module ShopSchemaClient
end

require_relative "shop_schema_client/metafield_type_resolver"
require_relative "shop_schema_client/shop_schema_composer"
require_relative "shop_schema_client/request_transformer"
require_relative "shop_schema_client/response_transformer"
require_relative "shop_schema_client/version"
