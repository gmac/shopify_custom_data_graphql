# frozen_string_literal: true

require "test_helper"

describe "ExtensionsSchema" do
  def setup
    @catalog = ShopifyCustomDataGraphQL::CustomDataCatalog.new
    @catalog.add_metafield({
      "key" => "metaobject_reference",
      "namespace" => "custom",
      "type" => { "name" => "metaobject_reference" },
      "validations" => [{
        "name" => "metaobject_definition_id",
        "value" => "gid://shopify/MetaobjectDefinition/Taco"
      }],
      "ownerType" => "PRODUCT"
    })
    @catalog.add_metaobject({
      "id" => "gid://shopify/MetaobjectDefinition/Taco",
      "name" => "Taco",
      "type" => "taco",
      "fieldDefinitions" => [{
        "key" => "name",
        "required" => false,
        "type" => { "name" => "single_line_text_field" },
        "validations" => []
      }]
    })
  end

  def test_to_extensions_definition_builds_minimal_extensions_document
    doc = ShopifyCustomDataGraphQL::SchemaComposer.new(
      load_base_admin_schema,
      @catalog,
    ).to_extensions_definition

    expected = %|
      directive @metafield(key: String!, type: String!) on FIELD_DEFINITION
      directive @metaobject(type: String!) on OBJECT
      extend type Product { extensions: ProductExtensions! }
      type ProductExtensions { metaobjectReference: TacoMetaobject @metafield(key: "custom.metaobject_reference", type: "metaobject_reference") }
      extend type QueryRoot { extensions: QueryRootExtensions! }
      type QueryRootExtensions { tacoMetaobjects(after: String, before: String, first: Int, last: Int): TacoMetaobjectConnection }
      type TacoMetaobject @metaobject(type: "taco") { handle: String! id: ID! name: String @metafield(key: "name", type: "single_line_text_field") system: Metaobject! }
      type TacoMetaobjectConnection { edges: [TacoMetaobjectEdge!]! nodes: [TacoMetaobject!]! pageInfo: PageInfo! }
      type TacoMetaobjectEdge { cursor: String! node: TacoMetaobject }
    |

    assert_equal expected.squish, doc.gsub(/"""[^"]+"""/, "").squish
  end
end
