# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class PreparedQuery
    DEFAULT_TRACER = Tracer.new
    EMPTY_HASH= {}

    class Result
      attr_reader :query, :tracer, :result

      def initialize(query:, tracer:, result:)
        @query = query
        @tracer = tracer
        @result = result
      end

      def to_h
        @result
      end
    end

    attr_reader :query, :transforms

    def initialize(params)
      @query = params["query"]
      @transforms = params["transforms"] || EMPTY_HASH
    end

    def as_json
      return EMPTY_HASH if base_query?

      {
        "query" => @query,
        "transforms" => @transforms,
      }
    end

    def to_json
      as_json.to_json
    end

    def perform(tracer = DEFAULT_TRACER, source_query: nil)
      query = source_query && base_query? ? source_query : @query
      raise ArgumentError, "A source_query is required with empty transformations" if query.nil?

      raw_result = tracer.span("proxy") { yield(query) }

      result = if @transforms.any?
        tracer.span("transform_response") do
          ResponseTransformer.new(@transforms).perform(raw_result)
        end
      else
        raw_result
      end

      Result.new(query: query, tracer: tracer, result: result)
    end

    private

    def base_query?
      @transforms.none?
    end
  end
end
