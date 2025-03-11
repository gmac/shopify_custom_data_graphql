# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shopify_custom_data_graphql/version"

Gem::Specification.new do |spec|
  spec.name          = "shopify_custom_data_graphql"
  spec.version       = ShopifyCustomDataGraphQL::VERSION
  spec.authors       = ["Greg MacWilliam"]
  spec.summary       = "A statically-typed GraphQL API for Shopify Metafields and Metaobjects."
  spec.description   = "A statically-typed GraphQL API for Shopify Metafields and Metaobjects."
  spec.homepage      = "https://github.com/gmac/shopify_custom_data_graphql"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata    = {
    "homepage_uri" => "https://github.com/gmac/shopify_custom_data_graphql",
    "changelog_uri" => "https://github.com/gmac/shopify_custom_data_graphql/releases",
    "source_code_uri" => "https://github.com/gmac/shopify_custom_data_graphql",
    "bug_tracker_uri" => "https://github.com/gmac/shopify_custom_data_graphql/issues",
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^test/})
  end
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "graphql", ">= 2.4.11"
  spec.add_runtime_dependency "activesupport", ">= 7.0.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.12"
end
