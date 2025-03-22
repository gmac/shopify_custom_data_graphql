# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/pride"
require "minitest/autorun"
require "graphql/response_validator"
require "json"

def load_base_admin_schema
  sdl = File.read("#{__dir__}/fixtures/admin_2025_01_public.graphql")
  schema = GraphQL::Schema.from_definition(sdl)
  schema.use(GraphQL::Schema::Visibility)
  schema
end

def load_shop_fixtures_catalog(app_id: nil)
  catalog = ShopifyCustomDataGraphQL::CustomDataCatalog.new(app_id: app_id)

  data = JSON.parse(File.read("#{__dir__}/fixtures/metafields.json"))
  data.each { catalog.add_metafield(_1) }

  data = JSON.parse(File.read("#{__dir__}/fixtures/metaobjects.json"))
  data.each { catalog.add_metaobject(_1) }

  catalog
end

def load_shop_fixtures_schema(app_id: nil)
  ShopifyCustomDataGraphQL::SchemaComposer.new(
    load_base_admin_schema,
    load_shop_fixtures_catalog(app_id: app_id),
  ).schema
end

$base_schema = nil
$app_schema = nil
$shop_schema = nil
$metafield_values = nil

def base_schema
  $base_schema ||= load_base_admin_schema
end

def app_schema
  $app_schema ||= load_shop_fixtures_schema(app_id: 123)
end

def shop_schema
  $shop_schema ||= load_shop_fixtures_schema
end

def metafield_values
  $metafield_values ||= JSON.parse(File.read("#{__dir__}/fixtures/metafield_values.json"))
end
