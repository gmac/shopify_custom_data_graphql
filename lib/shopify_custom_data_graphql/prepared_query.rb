# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class PreparedQuery
    GRAPHQL_PRINTER = GraphQL::Language::Printer.new
    DEFAULT_TRACER = Tracer.new
    EMPTY_HASH = {}.freeze

    class NoQueryError < StandardError; end

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

    attr_reader :transforms

    def initialize(query: nil, document: nil, transforms: nil)
      @query = query
      @document = document
      @transforms = transforms || EMPTY_HASH
    end

    def query
      @query ||= @document ? GRAPHQL_PRINTER.print(@document) : nil
    end

    def document
      @document ||= @query ? GraphQL.parse(@query) : nil
    end

    def transformed?
      @transforms.any?
    end

    def as_json
      return EMPTY_HASH unless transformed?

      {
        "query" => query,
        "transforms" => transforms,
      }
    end

    def to_json
      as_json.to_json
    end

    def perform(tracer = DEFAULT_TRACER)
      raise NoQueryError, "No query to execute" if query.nil?

      raw_result = tracer.span("proxy") { yield(query, @document) }

      result = if transformed?
        tracer.span("transform_response") do
          ResponseTransformer.new(@transforms).perform(raw_result)
        end
      else
        raw_result
      end

      Result.new(query: query, tracer: tracer, result: result)
    end
  end
end
