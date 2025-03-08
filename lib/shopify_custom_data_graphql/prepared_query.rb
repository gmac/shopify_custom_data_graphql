# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class PreparedQuery
    DEFAULT_TRACER = Tracer.new

    attr_reader :query, :transforms

    def initialize(params)
      @query = params["query"]
      @transforms = params["transforms"]

      unless @query && @transforms
        raise ArgumentError, "PreparedQuery requires params `query` and `transforms`"
      end
    end

    def has_transforms?
      @transforms.any?
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

    def perform(tracer = DEFAULT_TRACER, source_query: nil)
      # pass through source query when it requires no transforms
      # stops queries without transformations from taking up cache space
      return yield(source_query) if source_query && !has_transforms?

      response = tracer.span("proxy") do
        yield(@query)
      end
      tracer.span("transform_response") do
        ResponseTransformer.new(@transforms).perform(response)
      end
    end
  end
end
