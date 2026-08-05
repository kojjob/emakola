defmodule Emakola.Catalog.CachedCatalogTest do
  @moduledoc """
  Tests for the CachedCatalog module.

  Verifies that the cache wrapper correctly delegates to the cache
  and only calls the database on misses.
  """
  use ExUnit.Case, async: false

  alias Emakola.Cache.StoreCache

  setup do
    table_name = :test_cached_catalog_cache
    {:ok, pid} = StoreCache.start_link(name: table_name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{cache: table_name}
  end

  describe "cache key generation for storefront queries" do
    test "product listing keys include store_id" do
      store_id = "store-abc"
      key = StoreCache.cache_key(:products, store_id)
      assert key == "products:store-abc:all"
    end

    test "category product keys include category_id" do
      store_id = "store-abc"
      cat_id = "cat-123"
      key = StoreCache.cache_key(:products, store_id, category_id: cat_id)
      assert key == "products:store-abc:category:cat-123"
    end

    test "search keys include the search query" do
      store_id = "store-abc"
      key = StoreCache.cache_key(:products, store_id, search: "ankara fabric")
      assert key == "products:store-abc:search:ankara fabric"
    end

    test "category keys are separate from product keys" do
      store_id = "store-abc"
      product_key = StoreCache.cache_key(:products, store_id)
      category_key = StoreCache.cache_key(:categories, store_id)

      refute product_key == category_key
    end
  end

  describe "invalidate_store clears all store data" do
    test "clears products and categories for the target store only", %{cache: cache} do
      store_a = "store-a-#{:erlang.unique_integer([:positive])}"
      store_b = "store-b-#{:erlang.unique_integer([:positive])}"

      # Populate cache for two stores
      StoreCache.put(cache, StoreCache.cache_key(:products, store_a), ["product_a"])
      StoreCache.put(cache, StoreCache.cache_key(:categories, store_a), ["category_a"])
      StoreCache.put(cache, StoreCache.cache_key(:products, store_b), ["product_b"])

      # Invalidate store A
      StoreCache.invalidate_store(cache, store_a)

      # Store A entries are gone
      assert :miss == StoreCache.get(cache, StoreCache.cache_key(:products, store_a))
      assert :miss == StoreCache.get(cache, StoreCache.cache_key(:categories, store_a))

      # Store B entries remain
      assert {:hit, ["product_b"]} ==
               StoreCache.get(cache, StoreCache.cache_key(:products, store_b))
    end
  end

  describe "fetch caches successful results" do
    test "caches the fallback result on miss", %{cache: cache} do
      key = "products:test-store:all"
      call_count = :counters.new(1, [:atomics])

      # First call: cache miss, fallback called
      {:ok, result} =
        StoreCache.fetch(cache, key, fn ->
          :counters.add(call_count, 1, 1)
          {:ok, [%{id: "p1", title: "Ankara Fabric"}]}
        end)

      assert [%{id: "p1", title: "Ankara Fabric"}] == result
      assert 1 == :counters.get(call_count, 1)

      # Second call: cache hit, fallback NOT called
      {:ok, cached_result} =
        StoreCache.fetch(cache, key, fn ->
          :counters.add(call_count, 1, 1)
          {:ok, [%{id: "p2", title: "Should not appear"}]}
        end)

      assert [%{id: "p1", title: "Ankara Fabric"}] == cached_result
      assert 1 == :counters.get(call_count, 1)
    end

    test "does not cache errors from fallback", %{cache: cache} do
      key = "products:error-store:all"

      {:error, :database_error} =
        StoreCache.fetch(cache, key, fn ->
          {:error, :database_error}
        end)

      # Key should not be in cache
      assert :miss == StoreCache.get(cache, key)
    end
  end
end
