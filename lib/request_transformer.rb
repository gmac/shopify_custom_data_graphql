class RequestTransformer
  GRAPHQL_PRINTER = GraphQL::Language::Printer.new

  def initialize(shop_schema)
    @schema = shop_schema
    @owner_types = @schema.possible_types(@schema.get_type("HasMetafields")).to_set
  end

  def perform(query)
    document = GraphQL.parse(query)
    op = document.definitions.first
    op = op.merge(selections: transform_selections(@schema.query, op.selections))
    puts GRAPHQL_PRINTER.print(op)
  end

  private

  def transform_selections(parent_type, input_selections, path: [])
    is_metafield_owner_type = @owner_types.include?(parent_type)
    new_selections = []
    input_selections.each do |node|
      case node
      when GraphQL::Language::Nodes::Field
        path << (node.alias || node.name)
        next_type = parent_type.get_field(node.name).type.unwrap
        if is_metafield_owner_type && node.name == "extensions"
          new_selections.push(*build_custom_fields(next_type, node.selections))
        else
          sub_selections = transform_selections(next_type, node.selections, path: path)
          new_selections << node.merge(selections: sub_selections)
        end
        path.pop

      when GraphQL::Language::Nodes::InlineFragment
        next unless node.type.nil? || parent_type.graphql_name == node.type.name
        transform_selections(parent_type, node.selections, path: path)

      when GraphQL::Language::Nodes::FragmentSpread
        # fragment = @request.fragment_definitions[node.name]
        # next unless parent_type.graphql_name == fragment.type.name
        # transform_selections(parent_type, fragment.selections, path: path)

      end
    end

    new_selections
  end

  def build_custom_fields(parent_type, input_selections, metaobject_scope: false)
    input_selections.filter_map do |node|
      case node
      when GraphQL::Language::Nodes::Field
        field = parent_type.get_field(node.name)
        metafield_attrs = field.directives.find { _1.graphql_name == "metafield" }.arguments.keyword_arguments
        is_list = metafield_attrs[:type].start_with?("list.")
        is_reference = metafield_attrs[:type].end_with?("_reference")
        field_alias = "#{metaobject_scope ? "" : "__extensions__"}#{node.alias || node.name}"
        next_type = parent_type.get_field(node.name).type.unwrap

        selections = if is_reference && is_list
          conn_node_type = next_type.get_field("nodes").type.unwrap
          conn_selections = node.selections.map do |conn_node|
            case conn_node.name
            when "edges"
              edges_selections = conn_node.selections.map do |n|
                n.name == "node" ? n.merge(selections: build_reference(conn_node_type, n.selections)) : n
              end
              conn_node.merge(selections: edges_selections)
            when "nodes"
              conn_node.merge(selections: build_reference(conn_node_type, conn_node.selections))
            else
              conn_node
            end
          end

          [
            GraphQL::Language::Nodes::Field.new(
              name: "references",
              arguments: node.arguments,
              selections: conn_selections,
            )
          ]
        elsif is_reference
          [
            GraphQL::Language::Nodes::Field.new(
              name: "reference",
              selections: build_reference(next_type, node.selections),
            )
          ]
        else
          [GraphQL::Language::Nodes::Field.new(name: "value")]
        end

        GraphQL::Language::Nodes::Field.new(
          field_alias: field_alias,
          name: metaobject_scope ? "field" : "metafield",
          arguments: [GraphQL::Language::Nodes::Argument.new(name: "key", value: metafield_attrs[:key])],
          selections: selections,
        )
      end
    end
  end

  def build_reference(reference_type, input_selections)
    if reference_type.graphql_name.end_with?("Metaobject")
      [
        GraphQL::Language::Nodes::InlineFragment.new(
          type: GraphQL::Language::Nodes::TypeName.new(name: "Metaobject"),
          selections: build_custom_fields(reference_type, input_selections, metaobject_scope: true),
        )
      ]
    else
      [
        GraphQL::Language::Nodes::InlineFragment.new(
          type: GraphQL::Language::Nodes::TypeName.new(name: reference_type.graphql_name),
          selections: transform_selections(reference_type, input_selections, path: []),
        )
      ]
    end
  end
end
