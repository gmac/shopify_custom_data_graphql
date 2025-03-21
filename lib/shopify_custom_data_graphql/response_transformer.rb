# frozen_string_literal: true

module ShopifyCustomDataGraphQL
  class ResponseTransformer
    EMPTY_HASH = {}.freeze
    SCOPED_FIELD = /^#{Regexp.quote(RequestTransformer::RESERVED_PREFIX)}([^_]+)_(.+)/.freeze

    def initialize(transform_map)
      @transform_map = transform_map
    end

    def perform(result)
      result["data"] = transform_object_scope!(result["data"], @transform_map) if result["data"]
      result["errors"] = transform_errors!(result["errors"]) if result["errors"]
      result
    end

    private

    def transform_object_scope!(object_value, current_map)
      return nil if object_value.nil?

      if (fields = current_map["f"])
        fields.each do |field_name, next_map|
          field_transform = next_map["fx"]

          if field_transform && field_transform["t"] == RequestTransformer::NAMESPACE_TRANSFORM
            transform_namespace!(object_value, field_name)
          end

          next_value = object_value[field_name]
          next if next_value.nil?

          if field_transform && field_transform["t"] != RequestTransformer::NAMESPACE_TRANSFORM
            next_value = object_value[field_name] = transform_field_value(next_value, field_transform)
          end

          case next_value
          when Hash
            transform_object_scope!(next_value, next_map)
          when Array
            transform_list_scope!(next_value, next_map)
          end
        end
      end

      if (possible_types = current_map["if"])
        resolved_type = object_value.delete(RequestTransformer::HINT_TYPENAME)
        next_map = possible_types[resolved_type]

        # reduce mixed reference scopes to just the selected type's fields
        if current_map.dig("fx", "t") == "mixed_reference"
          base_fields = current_map["f"] || EMPTY_HASH
          scope_fields = next_map&.dig("f") || EMPTY_HASH
          object_value.select! { |k, _v| scope_fields.key?(k) || base_fields.key?(k) }
        end

        if next_map
          transform_object_scope!(object_value, next_map)
        end
      end

      object_value
    end

    def transform_list_scope!(list_value, current_map)
      list_value.each do |list_item|
        case list_item
        when Hash
          transform_object_scope!(list_item, current_map)
        when Array
          transform_list_scope!(list_item, current_map)
        end
      end
    end

    def transform_namespace!(object_value, scope_ns)
      scope = {}
      scope_prefix = "#{RequestTransformer::RESERVED_PREFIX}#{scope_ns}_"

      object_value.reject! do |key, value|
        next false unless key.start_with?(scope_prefix)

        scope[key.sub(scope_prefix, "")] = value
        true
      end

      object_value[scope_ns] = scope
    end

    def transform_field_value(field_value, transform)
      transform_type = transform["t"]
      case transform_type
      when RequestTransformer::STATIC_TYPENAME_TRANSFORM
        transform["v"]
      when RequestTransformer::METAOBJECT_TYPENAME_TRANSFORM
        MetafieldTypeResolver.metaobject_typename(field_value, app_id: @transform_map["a"])
      else
        MetafieldTypeResolver.resolve(transform_type, field_value, transform["s"])
      end
    end

    def transform_errors!(errors)
      errors.each do |error|
        error.delete("locations") if @transform_map.any?
        error["path"] = transform_error_path(error["path"]) if error["path"]
      end
    end

    def transform_error_path(path)
      transformed_path = []
      path.reduce([0, @transform_map]) do |(index, current_map)|
        key = path[index]
        if key.is_a?(String) && key.start_with?(RequestTransformer::RESERVED_PREFIX)
          m = key.match(SCOPED_FIELD)
          parent_name = m[1]
          child_name = m[2]
          transformed_path.push(parent_name, child_name)
          next_map = current_map.dig("f", parent_name, "f", child_name)
          return transformed_path unless next_map

          if (next_transform = next_map.dig("fx", "t"))
            next [index + 2, next_map] if MetafieldTypeResolver.reference?(next_transform)
          end
          [index + 1, next_map]
        else
          next_map = key.is_a?(String) ? current_map.dig("f", key) : current_map
          return path unless next_map

          transformed_path << key
          [index + 1, next_map]
        end
      end
      transformed_path
    end
  end
end
