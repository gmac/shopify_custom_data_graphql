# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    class Result < ShopSchemaClient::ShopQuery
      attr_reader :document, :transform_map

      def initialize(document, transform_map)
        @document = document
        @transform_map = transform_map
        super({
          "query" => GraphQL::Language::Printer.new.print(@document),
          "transforms" => @transform_map.as_json,
        })
      end
    end
  end
end
