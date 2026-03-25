defmodule Emakola.Catalog.CachedCatalog do
  @moduledoc """
  Cache-aware wrapper for storefront catalog queries.

  This module provides the same query interface as `Emakola.Catalog` but
  checks the ETS cache first, falling back to the database on cache miss.
  Only storefront-facing read queries are cached — admin queries bypass
  the cache entirely.

  ## Cached Queries

  - `list_products/1` — all active products for a store
  - `list_products_by_category/2` — active products in a category
  - `search_products/2` — product search results
  - `list_categories/1` — all categories for a store
  - `list_root_categories/1` — root-level categories for a store

  ## Cache Invalidation

  Call `invalidate_store/1` when products or categories change
  for a given store. This is typically triggered by admin create/update/delete
  actions.
  """

  alias Emakola.Cache.StoreCache

  @cache :emakola_store_cache
  @product_ttl :timer.minutes(5)
  @category_ttl :timer.minutes(10)

  # ── Storefront Product Queries ──

  @doc """
  Lists all active products for a store (storefront).
  Results are cached for #{div(@product_ttl, 60_000)} minutes.
  """
  def list_products(store_id) do
    key = StoreCache.cache_key(:products, store_id)

    StoreCache.fetch(@cache, key, [ttl: @product_ttl], fn ->
      products =
        store_id
        |> Emakola.Catalog.list_products_by_store_and_status!(:active)
        |> Ash.load!([:variant_count, :min_price, :max_price])

      {:ok, products}
    end)
  end

  @doc """
  Lists active products in a specific category for a store (storefront).
  Results are cached for #{div(@product_ttl, 60_000)} minutes.
  """
  def list_products_by_category(store_id, category_id) do
    key = StoreCache.cache_key(:products, store_id, category_id: category_id)

    StoreCache.fetch(@cache, key, [ttl: @product_ttl], fn ->
      products =
        category_id
        |> then(&Emakola.Catalog.list_products_by_category!(&1, store_id))
        |> Ash.load!([:variant_count, :min_price, :max_price])

      {:ok, products}
    end)
  end

  @doc """
  Searches products for a store (storefront).
  Search results are cached for #{div(@product_ttl, 60_000)} minutes.
  """
  def search_products(store_id, query) do
    key = StoreCache.cache_key(:products, store_id, search: query)

    StoreCache.fetch(@cache, key, [ttl: @product_ttl], fn ->
      products =
        query
        |> Emakola.Catalog.search_products!(store_id)
        |> Ash.load!([:variant_count, :min_price, :max_price])

      {:ok, products}
    end)
  end

  # ── Storefront Category Queries ──

  @doc """
  Lists all categories for a store (storefront).
  Results are cached for #{div(@category_ttl, 60_000)} minutes.
  """
  def list_categories(store_id) do
    key = StoreCache.cache_key(:categories, store_id)

    StoreCache.fetch(@cache, key, [ttl: @category_ttl], fn ->
      categories = Emakola.Catalog.list_categories_by_store!(store_id)
      {:ok, categories}
    end)
  end

  @doc """
  Lists root-level categories for a store (storefront).
  Results are cached for #{div(@category_ttl, 60_000)} minutes.
  """
  def list_root_categories(store_id) do
    key = StoreCache.cache_key(:categories, store_id, level: :roots)

    StoreCache.fetch(@cache, key, [ttl: @category_ttl], fn ->
      categories = Emakola.Catalog.list_root_categories!(store_id)
      {:ok, categories}
    end)
  end

  # ── Cache Invalidation ──

  @doc """
  Invalidates all cached catalog data for a store.

  Call this after any product or category create/update/delete operation.
  """
  def invalidate_store(store_id) do
    StoreCache.invalidate_store(@cache, store_id)
  end
end
