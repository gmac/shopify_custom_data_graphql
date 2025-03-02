# frozen_string_literal: true

module ShopSchemaClient
  class RequestTransformer
    class FieldTransform
      attr_reader :metafield_type, :selections

      def initialize(metafield_type, selections: nil, value: nil)
        @metafield_type = metafield_type
        @selections = selections
        @value = value
      end

      def merge!(other)
        if other.nil? || other.metafield_type != @metafield_type
          # GraphQL validates overlapping field selections for consistency, so this shouldn't happen.
          # If it does, it probably means one of a few possibilities:
          # 1. The query wasn't validated. Run static validatations and return errors.
          # 2. The query slips through a known bug in GraphQL Ruby's overlapping fields validation,
          #    see: https://github.com/rmosolgo/graphql-ruby/issues/4403. While Admin API allows this,
          #    we have to be more strict about it.
          raise ValidationError, "overlapping field selections must be the same"
        end
        if other.selections
          @selections ||= []
          @selections.push(*other.selections)
          @selections.tap(&:uniq!)
        end
      end

      def as_json
        {
          "t" => @metafield_type,
          "s" => @selections,
          "v" => @value,
        }.tap(&:compact!)
      end
    end

    class TransformationScope
      attr_reader :parent, :fields, :possible_types
      attr_accessor :field_transform

      def initialize(parent = nil, map_all_fields: false, app_id: nil)
        @parent = parent
        @possible_types = {}
        @fields = {}
        @field_transform = nil
        @map_all_fields = map_all_fields
        @app_id = app_id
      end

      def map_all_fields?
        @map_all_fields || @parent&.map_all_fields? || false
      end

      def merge!(other)
        other.fields.each do |k, s|
          if (existing_field = @fields[k])
            existing_field.merge!(s)
          else
            @fields[k] = s
          end
        end

        if other.field_transform
          if @field_transform
            @field_transform.merge!(other.field_transform)
          else
            @field_transform = other.field_transform
          end
        end

        self
      end

      def as_json
        map_all_fields = map_all_fields?

        fields = @fields.each_with_object({}) do |(k, v), m|
          info = v.as_json
          m[k] = info if map_all_fields || !info.empty?
        end

        possible_types = @possible_types.each_with_object({}) do |(k, v), m|
          info = v.as_json
          m[k] = info unless info.empty?
        end

        {
          "a" => @app_id,
          "fx" => @field_transform&.as_json,
          "f" => fields.empty? ? nil : fields,
          "if" => possible_types.empty? ? nil : possible_types,
        }.tap(&:compact!)
      end
    end

    class TransformationMap
      attr_reader :current_scope

      def initialize(app_id)
        @current_scope = TransformationScope.new(app_id: app_id)
      end

      def as_json
        @current_scope.as_json
      end

      def apply_field_transform(transform)
        if @current_scope.field_transform
          @current_scope.field_transform.merge!(transform)
        else
          @current_scope.field_transform = transform
        end
      end

      def field_breadcrumb(field)
        @current_scope = @current_scope.fields[field.alias || field.name] ||= TransformationScope.new(@current_scope)
        result = yield
        @current_scope = @current_scope.parent
        result
      end

      def type_breadcrumb(typenames, map_all_fields: false)
        origin = @current_scope
        branch = @current_scope = TransformationScope.new
        result = yield

        @current_scope = origin
        typenames.each do |typename|
          @current_scope.possible_types[typename] ||= TransformationScope.new(
            @current_scope,
            map_all_fields: map_all_fields,
          ).merge!(branch)
        end
        result
      end
    end
  end
end
