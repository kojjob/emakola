defmodule Emakola.Cache.StoreCache do
  @moduledoc """
  ETS-based cache for storefront read queries.

  Designed to reduce database load for product listings and category queries
  on the customer-facing storefront, where low-bandwidth mobile users in
  West Africa need fast responses.

  ## Design

  - ETS table owned by a GenServer for crash safety
  - TTL-based expiration (default 5 minutes)
  - Per-store invalidation for multi-tenant safety
  - Simple API: `get/2`, `put/3`, `fetch/4`, `invalidate/2`

  ## Cache Keys

  Keys follow the pattern `"resource:store_id:qualifier"`:

      "products:abc-123:all"
      "products:abc-123:status:active"
      "categories:abc-123:roots"

  Use `cache_key/2` and `cache_key/3` to generate consistent keys.

  ## Usage

      # Read-through pattern (preferred)
      StoreCache.fetch(:emakola_store_cache, key, fn ->
        {:ok, Emakola.Catalog.list_products_by_store!(store_id)}
      end)

      # Manual get/put
      case StoreCache.get(:emakola_store_cache, key) do
        {:hit, products} -> products
        :miss -> # fetch from DB and put
      end

      # Invalidate on write
      StoreCache.invalidate_store(:emakola_store_cache, store_id)
  """

  use GenServer

  @default_ttl :timer.minutes(5)
  @cleanup_interval :timer.minutes(1)
  @default_name :emakola_store_cache

  # ── Client API ──

  @doc """
  Starts the cache GenServer.

  ## Options

    - `:name` - ETS table name (default: `:emakola_store_cache`)
    - `:ttl` - Default TTL in milliseconds (default: 5 minutes)
    - `:cleanup_interval` - How often to sweep expired entries (default: 1 minute)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Retrieves a value from the cache.

  Returns `{:hit, value}` if found and not expired, or `:miss` otherwise.
  """
  @spec get(atom(), String.t()) :: {:hit, term()} | :miss
  def get(cache \\ @default_name, key) do
    case safe_lookup(cache, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:hit, value}
        else
          :miss
        end

      _ ->
        :miss
    end
  end

  @doc """
  Stores a value in the cache with an optional TTL.

  ## Options

    - `:ttl` - Time to live in milliseconds (default: 5 minutes)
  """
  @spec put(atom(), String.t(), term(), keyword()) :: :ok
  def put(cache \\ @default_name, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = System.monotonic_time(:millisecond) + ttl
    :ets.insert(cache, {key, value, expires_at})
    :ok
  end

  @doc """
  Read-through cache pattern. Returns cached value on hit, or calls
  the fallback function on miss and caches successful results.

  The fallback must return `{:ok, value}` or `{:error, reason}`.
  Only `{:ok, value}` results are cached.

  ## Options

    - `:ttl` - Time to live in milliseconds (default: 5 minutes)
  """
  @spec fetch(atom(), String.t(), keyword() | function(), function() | nil) ::
          {:ok, term()} | {:error, term()}
  def fetch(cache \\ @default_name, key, opts_or_fallback, fallback \\ nil)

  def fetch(cache, key, fallback, nil) when is_function(fallback, 0) do
    fetch(cache, key, [], fallback)
  end

  def fetch(cache, key, opts, fallback) when is_list(opts) and is_function(fallback, 0) do
    case get(cache, key) do
      {:hit, value} ->
        {:ok, value}

      :miss ->
        case fallback.() do
          {:ok, value} = result ->
            put(cache, key, value, opts)
            result

          error ->
            error
        end
    end
  end

  @doc """
  Invalidates a specific cache key.
  """
  @spec invalidate(atom(), String.t()) :: :ok
  def invalidate(cache \\ @default_name, key) do
    :ets.delete(cache, key)
    :ok
  end

  @doc """
  Invalidates all cache entries for a given store.

  This scans the ETS table for keys containing the store_id.
  Called when products or categories are created, updated, or deleted
  for a specific store.
  """
  @spec invalidate_store(atom(), String.t()) :: :ok
  def invalidate_store(cache \\ @default_name, store_id) do
    # Match all keys that contain the store_id
    :ets.foldl(
      fn {key, _value, _expires_at}, acc ->
        if String.contains?(key, store_id) do
          :ets.delete(cache, key)
        end

        acc
      end,
      :ok,
      cache
    )

    :ok
  end

  @doc """
  Clears the entire cache. Use sparingly.
  """
  @spec invalidate_all(atom()) :: :ok
  def invalidate_all(cache \\ @default_name) do
    :ets.delete_all_objects(cache)
    :ok
  end

  @doc """
  Generates a consistent cache key for storefront queries.

  ## Examples

      cache_key(:products, "store-123")
      #=> "products:store-123:all"

      cache_key(:categories, "store-123")
      #=> "categories:store-123:all"
  """
  @spec cache_key(atom(), String.t()) :: String.t()
  def cache_key(resource, store_id) do
    "#{resource}:#{store_id}:all"
  end

  @doc """
  Generates a cache key with additional qualifiers.

  ## Examples

      cache_key(:products, "store-123", status: :active)
      #=> "products:store-123:status:active"

      cache_key(:products, "store-123", category_id: "cat-456")
      #=> "products:store-123:category:cat-456"

      cache_key(:products, "store-123", search: "phone")
      #=> "products:store-123:search:phone"
  """
  @spec cache_key(atom(), String.t(), keyword()) :: String.t()
  def cache_key(resource, store_id, qualifiers) do
    suffix =
      qualifiers
      |> Enum.map(fn
        {:status, val} -> "status:#{val}"
        {:category_id, val} -> "category:#{val}"
        {:search, val} -> "search:#{val}"
        {key, val} -> "#{key}:#{val}"
      end)
      |> Enum.join(":")

    "#{resource}:#{store_id}:#{suffix}"
  end

  # ── GenServer Callbacks ──

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :name, @default_name)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)

    table =
      :ets.new(table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    schedule_cleanup(cleanup_interval)

    {:ok, %{table: table, cleanup_interval: cleanup_interval}}
  end

  @impl true
  def handle_info(:cleanup, %{table: table, cleanup_interval: interval} = state) do
    now = System.monotonic_time(:millisecond)

    :ets.foldl(
      fn {key, _value, expires_at}, acc ->
        if now >= expires_at, do: :ets.delete(table, key)
        acc
      end,
      :ok,
      table
    )

    schedule_cleanup(interval)
    {:noreply, state}
  end

  # ── Private ──

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp safe_lookup(table, key) do
    :ets.lookup(table, key)
  rescue
    ArgumentError -> []
  end
end
