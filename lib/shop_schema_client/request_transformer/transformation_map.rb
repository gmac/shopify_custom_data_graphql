# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    class FieldTransform
      def initialize(
        action,
        metafield_type: nil,
        selections: nil
      )
        @action = action
        @metafield_type = metafield_type
        @selections = selections
      end

      def as_json
        {
          "do" => @action,
          "t" => @metafield_type,
          "s" => @selections,
        }.tap(&:compact!)
      end
    end

    class TransformationScope
      attr_reader :parent, :fields
      attr_reader :field_transforms, :possible_types
      attr_accessor :has_extensions

      def initialize(parent = nil)
        @parent = parent
        @possible_types = {}
        @fields = {}
        @field_transforms = []
        @has_extensions = false
      end

      def as_json
        fields = @fields.each_with_object({}) do |(k, v), m|
          info = v.as_json
          m[k] = info unless info.empty?
        end

        possible_types = @possible_types.each_with_object({}) do |(k, v), m|
          info = v.as_json
          m[k] = info unless info.empty?
        end

        {
          "f" => fields.empty? ? nil : fields,
          "fx" => field_transforms.empty? ? nil : field_transforms.map(&:as_json).tap(&:uniq!),
          "ex" => @has_extensions ? true : nil,
          "if" => possible_types.empty? ? nil : possible_types,
        }.tap(&:compact!)
      end
    end

    class TransformationMap
      attr_reader :current_scope

      def initialize
        @current_scope = TransformationScope.new
      end

      def as_json
        @current_scope.as_json
      end

      def add_field_transform(transform)
        @current_scope.field_transforms << transform
      end

      def field_breadcrumb(ns)
        @current_scope = @current_scope.fields[ns] ||= TransformationScope.new(@current_scope)
        result = yield
        back
        result
      end

      def type_breadcrumb(types)
        @current_scope = @current_scope.possible_types[types] ||= TransformationScope.new(@current_scope)
        result = yield
        back
        result
      end

      private

      def back
        raise "TransformationMap cannot go back" if @current_scope.parent.nil?
        @current_scope = @current_scope.parent
      end
    end
  end
end
