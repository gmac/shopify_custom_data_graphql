# frozen_string_literal: true

require "test_helper"

describe "handle_introspection" do
  def test_no_action_for_only_root_fields
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ product }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do
      called = true
    end

    assert_equal false, called
  end

  def test_no_action_for_root_fields_with_typename
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ product __typename }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do
      called = true
    end

    assert_equal false, called
  end

  def test_action_with_no_errors_for_only_introspection
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ __schema }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do |errors|
      called = true
      assert errors.nil?
    end

    assert called, "expected to be called"
  end

  def test_action_with_no_errors_for_introspection_and_typename
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ __schema __typename }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do |errors|
      called = true
      assert errors.nil?
    end

    assert called, "expected to be called"
  end

  def test_action_with_errors_for_introspection_and_root_field
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ product __schema __typename }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do |errors|
      called = true
      assert errors
      assert_equal 1, errors.first.nodes.length
      assert_equal "Cannot combine root fields with introspection fields.", errors.first.to_h["message"]
    end

    assert called, "expected to be called"
  end

  def test_action_with_errors_for_introspection_and_root_field_across_inline_fragment
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ product ...on QueryRoot { __schema } }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do |errors|
      called = true
      assert_equal 1, errors.length
    end

    assert called, "expected to be called"
  end

  def test_action_with_errors_for_introspection_and_root_field_across_fragment_spread
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ product ...Boom } fragment Boom on QueryRoot { __schema }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do |errors|
      called = true
      assert_equal 1, errors.length
    end

    assert called, "expected to be called"
  end

  def test_gracefully_ignores_invalid_field_names
    called = false
    query = GraphQL::Query.new(shop_schema, %|{ sfoo }|)
    ShopifyCustomDataGraphQL.handle_introspection(query) do
      called = true
    end

    assert_equal false, called
  end
end
