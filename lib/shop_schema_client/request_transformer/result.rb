# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    class Result
      attr_reader :document
      attr_reader :transform_map

      def initialize(document, transform_map)
        @document = document
        @transform_map = transform_map
        @query = nil
        @transforms = nil
        @response_transformer = nil
      end

      def query
        @query ||= GraphQL::Language::Printer.new.print(@document)
      end

      def transforms
        @transforms ||= @transform_map.as_json
      end

      def response_transformer
        @response_transformer ||= ResponseTransformer.new(transforms)
      end

      def as_json
        {
          query: query,
          transforms: transforms,
        }
      end

      def to_json
        as_json.to_json
      end
    end
  end
end
