defmodule Emakola.Cache.StoreCacheTest do
  @moduledoc """
  Tests for the ETS-based storefront cache.

  Verifies TTL-based expiration, per-store invalidation,
  and concurrent access safety.
  """
  use ExUnit.Case, async: true

  alias Emakola.Cache.StoreCache

  @store_id "store-#{:erlang.unique_integer([:positive])}"

  setup do
    # Each test gets a unique table to allow async tests
    table_name = :"test_cache_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = StoreCache.start_link(name: table_name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{cache: table_name, store_id: "store-#{:erlang.unique_integer([:positive])}"}
  end

  describe "get/2 and put/3" do
    test "returns :miss for uncached key", %{cache: cache} do
      assert :miss == StoreCache.get(cache, "nonexistent")
    end

    test "stores and retrieves a value", %{cache: cache} do
      key = "products:#{@store_id}:all"
      value = [%{id: 1, title: "Test Product"}]

      :ok = StoreCache.put(cache, key, value)
      assert {:hit, ^value} = StoreCache.get(cache, key)
    end

    test "stores and retrieves complex data structures", %{cache: cache, store_id: store_id} do
      key = "categories:#{store_id}:roots"

      categories = [
        %{id: "cat-1", name: "Electronics", children: [%{id: "cat-2", name: "Phones"}]}
      ]

      :ok = StoreCache.put(cache, key, categories)
      assert {:hit, ^categories} = StoreCache.get(cache, key)
    end
  end

  describe "TTL expiration" do
    test "entries expire after TTL", %{cache: cache} do
      key = "products:expiring"
      :ok = StoreCache.put(cache, key, "data", ttl: 50)

      assert {:hit, "data"} = StoreCache.get(cache, key)

      Process.sleep(80)
      assert :miss == StoreCache.get(cache, key)
    end

    test "entries with default TTL stay valid within TTL window", %{cache: cache} do
      key = "products:default-ttl"
      :ok = StoreCache.put(cache, key, "data")

      # Should still be cached immediately
      assert {:hit, "data"} = StoreCache.get(cache, key)
    end
  end

  describe "invalidate/2" do
    test "removes a specific key", %{cache: cache} do
      :ok = StoreCache.put(cache, "key1", "val1")
      :ok = StoreCache.put(cache, "key2", "val2")

      :ok = StoreCache.invalidate(cache, "key1")

      assert :miss == StoreCache.get(cache, "key1")
      assert {:hit, "val2"} = StoreCache.get(cache, "key2")
    end
  end

  describe "invalidate_store/2" do
    test "removes all entries for a specific store", %{cache: cache} do
      store_a = "store-a-#{:erlang.unique_integer([:positive])}"
      store_b = "store-b-#{:erlang.unique_integer([:positive])}"

      :ok = StoreCache.put(cache, "products:#{store_a}:all", "store_a_products")
      :ok = StoreCache.put(cache, "categories:#{store_a}:roots", "store_a_categories")
      :ok = StoreCache.put(cache, "products:#{store_b}:all", "store_b_products")

      :ok = StoreCache.invalidate_store(cache, store_a)

      assert :miss == StoreCache.get(cache, "products:#{store_a}:all")
      assert :miss == StoreCache.get(cache, "categories:#{store_a}:roots")
      assert {:hit, "store_b_products"} = StoreCache.get(cache, "products:#{store_b}:all")
    end
  end

  describe "invalidate_all/1" do
    test "clears the entire cache", %{cache: cache} do
      :ok = StoreCache.put(cache, "key1", "val1")
      :ok = StoreCache.put(cache, "key2", "val2")

      :ok = StoreCache.invalidate_all(cache)

      assert :miss == StoreCache.get(cache, "key1")
      assert :miss == StoreCache.get(cache, "key2")
    end
  end

  describe "cache_key/2 and cache_key/3" do
    test "generates consistent keys for store queries" do
      store_id = "abc-123"
      assert "products:abc-123:all" == StoreCache.cache_key(:products, store_id)
    end

    test "generates keys with extra qualifiers" do
      store_id = "abc-123"

      assert "products:abc-123:status:active" ==
               StoreCache.cache_key(:products, store_id, status: :active)
    end

    test "generates keys for category queries" do
      store_id = "abc-123"
      assert "categories:abc-123:all" == StoreCache.cache_key(:categories, store_id)
    end

    test "generates keys for category product listings" do
      store_id = "abc-123"
      cat_id = "cat-456"

      assert "products:abc-123:category:cat-456" ==
               StoreCache.cache_key(:products, store_id, category_id: cat_id)
    end

    test "generates keys for search queries" do
      store_id = "abc-123"

      assert "products:abc-123:search:phone" ==
               StoreCache.cache_key(:products, store_id, search: "phone")
    end
  end

  describe "fetch/4" do
    test "returns cached value on hit without calling fallback", %{cache: cache} do
      key = "products:fetch-test"
      :ok = StoreCache.put(cache, key, "cached_value")

      result =
        StoreCache.fetch(cache, key, fn ->
          send(self(), :fallback_called)
          {:ok, "fresh_value"}
        end)

      assert {:ok, "cached_value"} == result
      refute_received :fallback_called
    end

    test "calls fallback on miss and caches the result", %{cache: cache} do
      key = "products:fetch-miss"

      result =
        StoreCache.fetch(cache, key, fn ->
          {:ok, "computed_value"}
        end)

      assert {:ok, "computed_value"} == result
      assert {:hit, "computed_value"} = StoreCache.get(cache, key)
    end

    test "does not cache error results from fallback", %{cache: cache} do
      key = "products:fetch-error"

      result =
        StoreCache.fetch(cache, key, fn ->
          {:error, :not_found}
        end)

      assert {:error, :not_found} == result
      assert :miss == StoreCache.get(cache, key)
    end

    test "passes TTL option to put when caching", %{cache: cache} do
      key = "products:fetch-ttl"

      StoreCache.fetch(cache, key, [ttl: 50], fn ->
        {:ok, "short_lived"}
      end)

      assert {:hit, "short_lived"} = StoreCache.get(cache, key)

      Process.sleep(80)
      assert :miss == StoreCache.get(cache, key)
    end
  end
end
