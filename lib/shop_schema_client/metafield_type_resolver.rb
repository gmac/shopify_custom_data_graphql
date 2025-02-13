# frozen_string_literal: true

module ShopSchemaClient
  class MetafieldTypeResolver
    CONNECTION_TYPE_SUFFIX = "Connection"
    EXTENSIONS_TYPE_SUFFIX = "Extensions"
    METAOBJECT_TYPE_SUFFIX = "Metaobject"

    COLOR_TYPENAME = "ColorMetatype"
    DIMENSION_TYPENAME = "DimensionMetatype"
    MONEY_TYPENAME = "MoneyV2"
    RATING_TYPENAME = "RatingMetatype"
    RICH_TEXT_TYPENAME = "RichTextMetatype"
    VOLUME_TYPENAME = "VolumeMetatype"
    WEIGHT_TYPENAME = "Weight"

    class << self
      def connection_typename(native_typename)
        "#{native_typename}#{CONNECTION_TYPE_SUFFIX}"
      end

      def connection_type?(type_name)
        type_name.end_with?(CONNECTION_TYPE_SUFFIX)
      end

      def metaobject_typename(metaobject_type)
        metaobject_type[0] = metaobject_type[0].upcase
        metaobject_type.gsub!(/_\w/) { _1[1].upcase }
        "#{metaobject_type}#{METAOBJECT_TYPE_SUFFIX}"
      end

      def metaobject_type?(type_name)
        type_name != METAOBJECT_TYPE_SUFFIX && type_name.end_with?(METAOBJECT_TYPE_SUFFIX)
      end

      def extensions_typename(native_typename)
        "#{native_typename}#{EXTENSIONS_TYPE_SUFFIX}"
      end

      def extensions_type?(type_name)
        type_name.end_with?(EXTENSIONS_TYPE_SUFFIX)
      end

      def list?(type_name)
        type_name.start_with?("list.")
      end

      def reference?(type_name)
        type_name.end_with?("_reference")
      end

      def resolve(type_name, value, selections)
        is_list = list?(type_name)
        is_reference = reference?(type_name)

        if is_reference && is_list
          return value["references"]
        elsif is_reference
          return value["reference"]
        else
          value = value["value"]
        end

        return nil if value.nil? || value.empty?

        case type_name
        when "boolean"
          value == "true"
        when "color"
          value
        when "list.color"
          JSON.parse(value)
        when "date", "date_time"
          Time.parse(value)
        when "list.date", "list.date_time"
          JSON.parse(value).map! { Time.parse(_1) }
        when "dimension"
          unit_value_with_selections(JSON.parse(value), selections, DIMENSION_TYPENAME)
        when "list.dimension"
          JSON.parse(value).map! { unit_value_with_selections(_1, selections, DIMENSION_TYPENAME) }
        when "id"
          value
        when "json"
          JSON.parse(value)
        when "language"
          value
        when "link"
          value
        when "list.link"
          JSON.parse(value)
        when "money"
          money_with_selections(JSON.parse(value), selections)
        when "multi_line_text_field"
          value
        when "number_decimal"
          Float(value)
        when "list.number_decimal"
          JSON.parse(value).map!(&:Float)
        when "number_integer"
          Integer(value)
        when "list.number_integer"
          JSON.parse(value).map!(&:Integer)
        when "rating"
          rating_with_selections(JSON.parse(value), selections)
        when "list.rating"
          JSON.parse(value).map! { rating_with_selections(_1, selections) }
        when "rich_text_field"
          JSON.parse(value)
        when "single_line_text_field"
          value
        when "list.single_line_text_field"
          JSON.parse(value).map!(&:to_s)
        when "url"
          value
        when "list.url"
          JSON.parse(value)
        when "volume"
          unit_value_with_selections(JSON.parse(value), selections, VOLUME_TYPENAME)
        when "list.volume"
          JSON.parse(value).map! { unit_value_with_selections(_1, selections, VOLUME_TYPENAME) }
        when "weight"
          unit_value_with_selections(JSON.parse(value), selections, WEIGHT_TYPENAME)
        when "list.weight"
          JSON.parse(value).map! { unit_value_with_selections(_1, selections, WEIGHT_TYPENAME) }
        else
          raise "Unknown metafield type `#{metafield_type}`"
        end
      rescue JSON::ParserError
        nil
      end

      def unit_value_with_selections(obj, selections, type_name)
        selections.each_with_object({}) do |node, memo|
          # should also anticipate fragments...
          field_name = node.alias || node.name
          case node.name
          when "unit"
            memo[field_name] = obj["unit"]
          when "value"
            memo[field_name] = Float(obj["value"])
          when "__typename"
            memo[field_name] = type_name
          end
        end
      end

      def money_with_selections(obj, selections)
        selections.each_with_object({}) do |node, memo|
          # should also anticipate fragments...
          field_name = node.alias || node.name
          case node.name
          when "amount"
            memo[field_name] = Float(obj["amount"])
          when "currencyCode"
            memo[field_name] = obj["currency"]
          when "__typename"
            memo[field_name] = MONEY_TYPENAME
          end
        end
      end

      def rating_with_selections(obj, selections)
        selections.each_with_object({}) do |node, memo|
          # should also anticipate fragments...
          field_name = node.alias || node.name
          case node.name
          when "min"
            memo[field_name] = Float(obj["scale_min"])
          when "max"
            memo[field_name] = Float(obj["scale_max"])
          when "value"
            memo[field_name] = Float(obj["value"])
          when "__typename"
            memo[field_name] = RATING_TYPENAME
          end
        end
      end
    end
  end
end
