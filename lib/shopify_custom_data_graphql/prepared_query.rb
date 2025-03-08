# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class PreparedQuery
    attr_reader :query, :transforms

    def initialize(params)
      @query = params["query"]
      @transforms = params["transforms"]

      unless @query && @transforms
        raise ArgumentError, "PreparedQuery requires params `query` and `transforms`"
      end
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
      ResponseTransformer.new(@transforms).perform(yield(@query))
    end
  end
end
