# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    class TransformAction
      def initialize(
        action,
        metafield_type: nil,
        selections: nil,
        typename: nil
      )
        @action = action
        @metafield_type = metafield_type
        @selections = selections
        @typename = typename
      end

      def as_json
        {
          "do" => @action,
          "t" => @metafield_type,
          "s" => @selections,
          "if" => @typename,
        }.tap(&:compact!)
      end
    end

    class TransformationScope
      attr_reader :parent, :children, :actions, :namespace

      def initialize(parent = nil, namespace = nil)
        @parent = parent
        @namespace = namespace
        @children = {}
        @actions = []
      end

      def as_json
        paths = @children.each_with_object({}) do |(k, v), m|
          info = v.as_json
          m[k] = info unless info.empty?
        end

        {
          "f" => paths.empty? ? nil : paths,
          "do" => actions.empty? ? nil : actions.map(&:as_json).tap(&:uniq!),
        }.tap(&:compact!)
      end
    end

    class TransformationMap
      attr_reader :current_scope

      def initialize
        @current_scope = TransformationScope.new
      end

      def forward(ns)
        @current_scope = @current_scope.children[ns] ||= TransformationScope.new(@current_scope, ns)
      end

      def back
        raise "TransformationMap cannot go back" if @current_scope.parent.nil?
        @current_scope = @current_scope.parent
      end

      def step(namespace)
        forward(namespace)
        result = yield
        back
        result
      end

      def add_action(action)
        @current_scope.actions << action
      end

      def as_json
        @current_scope.as_json
      end
    end
  end
end
