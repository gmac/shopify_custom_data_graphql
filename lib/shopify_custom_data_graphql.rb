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

  class Tracer < Hash
    def span(span_name)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      self[span_name] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1_000
      result
    end
  end

  class << self
    def handle_introspection(query)
      return unless query.query?

      introspection_nodes = map_root_introspection_nodes(query, query.schema.query, query.selected_operation.selections)
      return if introspection_nodes.all? { _1.nil? || _1.name == "__typename" }

      errors = if introspection_nodes.any?(&:nil?)
        introspection_nodes.reject! { _1.nil? || _1.name == "__typename" }
        [
          GraphQL::StaticValidation::Error.new(
            "Cannot combine root fields with introspection fields.",
            nodes: introspection_nodes,
          ),
        ]
      end

      yield(errors)
      nil
    end

    private

    def map_root_introspection_nodes(query, parent_type, selections, nodes: [])
      selections.each do |node|
        case node
        when GraphQL::Language::Nodes::Field
          field = query.get_field(parent_type, node.name)
          nodes << (field&.introspection? ? node : nil)
        when GraphQL::Language::Nodes::InlineFragment
          map_root_introspection_nodes(query, parent_type, node.selections, nodes: nodes)
        when GraphQL::Language::Nodes::FragmentSpread
          fragment_selections = query.fragments[node.name].selections
          map_root_introspection_nodes(query, parent_type, fragment_selections, nodes: nodes)
        end
      end
      nodes
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
