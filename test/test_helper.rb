# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'bundler/setup'
Bundler.require(:default, :test)

require 'minitest/pride'
require 'minitest/autorun'

def load_admin_schema
  sdl = File.read("#{__dir__}/fixtures/admin_2025_01_public.graphql")
  GraphQL::Schema.from_definition(sdl)
end

def load_metaschema_catalog
  data = JSON.parse(File.read("#{__dir__}/fixtures/shop_metaschema.json"))
  metaobjects = data.dig("data", "metaobjectDefinitions", "nodes").map do |metaobject_def|
    ShopSchemaClient::ShopSchemaComposer::MetaobjectDefinition.from_graphql(metaobject_def)
  end

  metafields = data.dig("data", "productFields", "nodes").map do |metafield_def|
    ShopSchemaClient::ShopSchemaComposer::MetafieldDefinition.from_graphql(metafield_def)
  end

  catalog = ShopSchemaClient::ShopSchemaComposer::MetaschemaCatalog.new
  catalog.add_metaobjects(metaobjects)
  catalog.add_metafields(metafields)
  catalog
end
