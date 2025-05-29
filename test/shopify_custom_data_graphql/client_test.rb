# frozen_string_literal: true

require "test_helper"

describe "ExtensionsSchema" do
  def setup
    @client = ShopifyCustomDataGraphQL::Client.new
    @client.instance_variable_set(:@schema, shop_schema)
  end

  def test_to_extensions_definition_builds_minimal_extensions_document
    # todo...
  end
end
