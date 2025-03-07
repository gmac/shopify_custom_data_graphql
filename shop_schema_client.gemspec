# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shop_schema_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'shop_schema_client' # 'shopify_metafields_graphql_api'
  spec.version       = ShopSchemaClient::VERSION
  spec.authors       = ['Greg MacWilliam']
  spec.summary       = 'A client for consuming Shopify metafields and metaobjects through schema projections.'
  spec.description   = 'Build a shop-specific GraphQL schema and use it to make requests.'
  spec.homepage      = 'https://github.com/gmac/shop-schema-client'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata    = {
    'homepage_uri' => 'https://github.com/gmac/shop-schema-client',
    'changelog_uri' => 'https://github.com/gmac/shop-schema-client/releases',
    'source_code_uri' => 'https://github.com/gmac/shop-schema-client',
    'bug_tracker_uri' => 'https://github.com/gmac/shop-schema-client/issues',
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^test/})
  end
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'graphql', '>= 2.4.11'
  spec.add_runtime_dependency 'activesupport', '>= 7.0.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.12'
end
