# frozen_string_literal: true

module ShopSchemaClient
  class ShopQuery
    attr_reader :query, :transforms, :response_transformer

    def initialize(params)
      @query = params["query"]
      @transforms = params["transforms"]
      @response_transformer = ResponseTransformer.new(@transforms)
    end

    def as_json
      {
        "query" => @query,
        "transforms" => @transforms,
      }
    end

    def to_json
      as_json.to_json
    end

    def perform
      @response_transformer.perform(yield(@query))
    end
  end
end
