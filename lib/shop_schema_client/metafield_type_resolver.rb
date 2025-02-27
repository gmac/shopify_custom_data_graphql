# frozen_string_literal: true

module ShopSchemaClient
  class MetafieldTypeResolver
    CONNECTION_TYPE_SUFFIX = "Connection"
    EXTENSIONS_TYPE_SUFFIX = "Extensions"
    METAOBJECT_TYPE_SUFFIX = "Metaobject"
    MIXED_METAOBJECT_TYPE_PREFIX = "MixedMetaobject"

    COLOR_TYPENAME = "ColorMetatype"
    DIMENSION_TYPENAME = "DimensionMetatype"
    MONEY_TYPENAME = "MoneyV2"
    RATING_TYPENAME = "RatingMetatype"
    RICH_TEXT_TYPENAME = "RichTextMetatype"
    VOLUME_TYPENAME = "VolumeMetatype"
    WEIGHT_TYPENAME = "Weight"

    UNITS_MAP = {
      # dimensions
      "cm" => "CENTIMETERS",
      "in" => "INCHES",
      "ft" => "FEET",
      "mm" => "MILLIMETERS",
      "m"  => "METERS",
      "yd" => "YARDS",
      # volumes
      "ml" => "MILLILITERS",
      "cl" => "CENTILITERS",
      "L" => "LITERS",
      "m3" => "CUBIC_METERS",
      "us_fl_oz" => "FLUID_OUNCES",
      "us_pt" => "PINTS",
      "us_qt" => "QUARTS",
      "us_gal" => "GALLONS",
      "imp_fl_oz" => "IMPERIAL_FLUID_OUNCES",
      "imp_pt" => "IMPERIAL_PINTS",
      "imp_qt" => "IMPERIAL_QUARTS",
      "imp_gal" => "IMPERIAL_GALLONS",
      # weights
      "g"  => "GRAMS",
      "kg" => "KILOGRAMS",
      "lb" => "POUNDS",
      "oz" => "OUNCES",
    }.freeze

    class << self
      def connection_typename(native_typename)
        "#{native_typename}#{CONNECTION_TYPE_SUFFIX}"
      end

      def connection_type?(type_name)
        type_name.end_with?(CONNECTION_TYPE_SUFFIX)
      end

      def metaobject_typename(metaobject_type)
        "#{metaobject_type.camelize}#{METAOBJECT_TYPE_SUFFIX}"
      end

      def metaobject_type?(type_name)
        type_name != METAOBJECT_TYPE_SUFFIX && type_name.end_with?(METAOBJECT_TYPE_SUFFIX)
      end

      def mixed_metaobject_type?(type_name)
        type_name.start_with?(MIXED_METAOBJECT_TYPE_PREFIX)
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
          value = value["jsonValue"]
        end

        return nil if value.nil?

        case type_name
        when "boolean"
          value == true
        when "color", "list.color", "date", "list.date", "date_time", "list.date_time"
          value
        when "dimension"
          unit_value_with_selections(value, selections, DIMENSION_TYPENAME)
        when "list.dimension"
          value.map! { unit_value_with_selections(_1, selections, DIMENSION_TYPENAME) }
        when "id", "json"
          value
        when "language"
          value.upcase
        when "link", "list.link"
          value
        when "money"
          money_with_selections(value, selections)
        when "multi_line_text_field"
          value
        when "number_decimal"
          Float(value)
        when "list.number_decimal"
          value.map! { Float(_1) }
        when "number_integer"
          Integer(value)
        when "list.number_integer"
          value.map! { Integer(_1) }
        when "rating"
          rating_with_selections(value, selections)
        when "list.rating"
          value.map! { rating_with_selections(_1, selections) }
        when "rich_text_field", "single_line_text_field", "list.single_line_text_field", "url", "list.url"
          value
        when "volume"
          unit_value_with_selections(value, selections, VOLUME_TYPENAME)
        when "list.volume"
          value.map! { unit_value_with_selections(_1, selections, VOLUME_TYPENAME) }
        when "weight"
          unit_value_with_selections(value, selections, WEIGHT_TYPENAME)
        when "list.weight"
          value.map! { unit_value_with_selections(_1, selections, WEIGHT_TYPENAME) }
        else
          raise "Unknown metafield type `#{metafield_type}`"
        end
      end

      def unit_value_with_selections(obj, selections, type_name)
        selections.each_with_object({}) do |sel, memo|
          field_name, node_name = selection_alias_and_field(sel)
          case node_name
          when "unit"
            unit = obj["unit"]
            memo[field_name] = UNITS_MAP.fetch(unit, unit)
          when "value"
            memo[field_name] = Float(obj["value"])
          when "__typename"
            memo[field_name] = type_name
          end
        end
      end

      def money_with_selections(obj, selections)
        selections.each_with_object({}) do |sel, memo|
          field_name, node_name = selection_alias_and_field(sel)
          case node_name
          when "amount"
            memo[field_name] = Float(obj["amount"])
          when "currencyCode"
            memo[field_name] = obj["currency_code"]
          when "__typename"
            memo[field_name] = MONEY_TYPENAME
          end
        end
      end

      def rating_with_selections(obj, selections)
        selections.each_with_object({}) do |sel, memo|
          field_name, node_name = selection_alias_and_field(sel)
          case node_name
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

      def selection_alias_and_field(sel)
        sel.include?(":") ? sel.split(":") : [sel, sel]
      end
    end
  end
end
