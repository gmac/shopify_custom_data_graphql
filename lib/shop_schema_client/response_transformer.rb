# frozen_string_literal: true

module ShopSchemaClient
  class ResponseTransformer
    def initialize(transform_map)
      @transform_map = transform_map
    end

    def perform(result)
      result["data"] = transform_object_scope(result["data"], @transform_map) if result["data"]
      result
    end

    private

    def transform_object_scope(object_value, current_map)
      return nil if object_value.nil?

      if (fields = current_map["f"])
        fields.each do |field_name, next_map|
          field_transform = next_map["fx"]

          if field_transform && field_transform["t"] == RequestTransformer::CUSTOM_SCOPE_TRANSFORM
            expand_custom_scope(object_value, field_name)
          end

          next_value = object_value[field_name]
          next if next_value.nil?

          if field_transform && field_transform["t"] != RequestTransformer::CUSTOM_SCOPE_TRANSFORM
            next_value = object_value[field_name] = transform_field_value(next_value, field_transform)
          end

          case next_value
          when Hash
            transform_object_scope(next_value, next_map)
          when Array
            transform_list_scope(next_value, next_map)
          end
        end
      end

      if (possible_types = current_map["if"])
        actual_type = object_value[RequestTransformer::TYPENAME_HINT]
        possible_types.each do |possible_type, next_map|
          transform_object_scope(object_value, next_map) if possible_type == actual_type
        end

        object_value.delete(RequestTransformer::TYPENAME_HINT)
      end

      object_value
    end

    def transform_list_scope(list_value, current_map)
      list_value.each do |list_item|
        case list_item
        when Hash
          transform_object_scope(list_item, current_map)
        when Array
          transform_list_scope(list_item, current_map)
        end
      end
    end

    def transform_field_value(field_value, transform)
      metafield_type = transform["t"]
      case metafield_type
      when "static_typename"
        transform["v"]
      when "metaobject_typename"
        MetafieldTypeResolver.metaobject_typename(field_value)
      else
        MetafieldTypeResolver.resolve(metafield_type, field_value, transform["s"])
      end
    end

    def expand_custom_scope(object_value, scope_ns)
      scope = {}
      scope_prefix = "#{RequestTransformer::RESERVED_PREFIX}#{scope_ns}_"

      object_value.reject! do |key, value|
        next false unless key.start_with?(scope_prefix)

        scope[key.sub(scope_prefix, "")] = value
        true
      end

      object_value[scope_ns] = scope
    end
  end
end
