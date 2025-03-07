# frozen_string_literal: true

module ShopSchemaClient
  class Client
    class LruCache
      def initialize(max_bytesize)
        @data = {}
        @bytesizes = {}
        @current_bytesize = 0
        @max_bytesize = max_bytesize
        @prune_bytesize = max_bytesize - (max_bytesize * 0.2).to_i
      end

      def get(key)
        found = true
        value = @data.delete(key) { found = false }
        @data[key] = value if found
        value
      end

      def set(key, value, bytesize)
        @current_bytesize -= @bytesizes.delete(key).to_i
        @current_bytesize += bytesize
        @bytesizes[key] = bytesize
        @data[key] = value

        if @current_bytesize > @max_bytesize
          while @current_bytesize > @prune_bytesize
            @current_bytesize -= @bytesizes.delete(@data.shift[0]).to_i
          end
        end
        value
      end
    end

    def initialize(
      shop_url:,
      access_token:,
      api_version: "2025-01",
      app_schema: false,
      base_namespaces: nil,
      scoped_namespaces: nil,
      file_cache: nil
    )
      @base_namespaces = base_namespaces
      @scoped_namespaces = scoped_namespaces
      @file_cache = file_cache

      if app_schema
        @base_namespaces ||= ["$app"]
        @scoped_namespaces ||= ["custom", "my_fields", "app--*"]
      else
        @base_namespaces ||= ["custom"]
        @scoped_namespaces ||= ["my_fields", "app--*"]
      end

      @client = AdminApiClient.new(
        shop_url: shop_url,
        access_token: access_token,
        api_version: api_version,
      )

      @cache = LruCache.new(5.megabytes)
      @on_cache_read = nil
      @on_cache_write = nil
    end

    def schema
      catalog ||= SchemaCatalog.new(
        app_schema: app_schema,
        base_namespaces: base_namespaces,
        scoped_namespaces: scoped_namespaces,
        client: @client,
      )
    end

    def execute(query: nil, variables: nil, operation_name: nil)
      prepared_query = prepare_query(query, operation_name)
      prepared_query.perform { @client.fetch(_1, variables: variables) }
    rescue ValidationError => e
      { "errors" => [{ "message" => e.message }] }
    end

    def on_cache_read(&block)
      raise ArgumentError, "A cache read block is required." unless block_given?
      @on_cache_read = block
    end

    def on_cache_write(&block)
      raise ArgumentError, "A cache write block is required." unless block_given?
      @on_cache_write = block
    end

    private

    def prepare_query(query, operation_name)
      digest = Digest::MD5.hexdigest([query, operation_name, VERSION].join(" "))
      hot_query = @lru.get(digest)
      return hot_query if hot_query

      if @on_cache_read && (json = @on_cache_read.call(digest))
        prepared_query = PreparedQuery.new(JSON.parse(json))
        return @lru.set(digest, prepared_query, json.bytesize)
      end

      query = GraphQL::Query.new(schema, query: query, operation_name: operation_name)
      errors = schema.static_validator.validate(query)[:errors]
      raise ValidationError, errors.map(&:to_h).to_s if errors.any?

      prepared_query = RequestTransformer.new(query).perform.to_prepared_query
      json = prepared_query.to_json
      @on_cache_write.call(digest, json) if @on_cache_write
      @lru.set(digest, prepared_query, json.bytesize)
    end
  end
end
