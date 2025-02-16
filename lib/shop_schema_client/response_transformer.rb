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

      expand_extensions(object_value) if current_map["ex"]

      if (fields = current_map["f"])
        fields.each do |field_name, next_map|
          next_value = object_value[field_name]
          next if next_value.nil?

          if (transforms = next_map["fx"])
            next_value = object_value[field_name] = transforms.reduce(next_value) do |val, xform|
              transform_field_value(val, xform)
            end
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
        actual_type = object_value["__typehint"]
        possible_types.each do |possible_type, next_map|
          next unless possible_type == actual_type || possible_type.split("|").include?(actual_type)

          transform_object_scope(object_value, next_map)
        end

        object_value.delete("__typehint")
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

    def transform_field_value(object_value, transform)
      case transform["do"]
      when "mf_val", "mf_ref", "mf_refs"
        MetafieldTypeResolver.resolve(transform["t"], object_value, transform["s"])
      when "mo_typename"
        MetafieldTypeResolver.metaobject_typename(object_value)
      when "ex_typename"
        MetafieldTypeResolver.extensions_typename(object_value)
      end
    end

    def expand_extensions(object_value)
      extensions_scope = {}
      object_value.reject! do |key, value|
        next false unless key.start_with?(RequestTransformer::EXTENSIONS_PREFIX)

        extensions_scope[key.sub(RequestTransformer::EXTENSIONS_PREFIX, "")] = value
        true
      end

      object_value["extensions"] = extensions_scope
    end
  end
end
