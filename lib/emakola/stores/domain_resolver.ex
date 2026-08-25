defmodule Emakola.Stores.DomainResolver do
  @moduledoc """
  Cached host → store resolution, and the store's primary custom host.

  Both lookups sit on hot paths: `lookup/1` runs on every request to a branded
  host *and* on every LiveView socket connect (`check_origin`), and
  `primary_host/1` runs wherever a canonical URL is rendered — including the
  sitemap. Neither was cached before.

  Two deliberate choices:

    * **A minimal map is cached, never a `%StoreDomain{}` with a loaded
      `:store`.** A cached store struct would keep serving stale themes and a
      stale suspension status long after the store changed.
    * **Misses are cached too**, on a short TTL. `check_origin` is reachable by
      anyone with a socket, so an uncached miss is a database read per probe.

  `Emakola.Cache.StoreCache.fetch/4` only stores `{:ok, value}`, so a miss is
  represented as `{:ok, :none}` internally and unwrapped at the boundary.
  """

  require Logger

  alias Emakola.Cache.StoreCache
  alias Emakola.Stores

  @cache :emakola_store_cache
  @host_ttl :timer.minutes(5)
  # Short, because it is what an unknown host costs an attacker.
  @miss_ttl :timer.seconds(60)

  @type resolved :: %{
          store_id: String.t(),
          slug: String.t(),
          status: atom(),
          serve_in_place?: boolean(),
          primary?: boolean()
        }

  @doc "Resolves a hostname to its store, or `:none`."
  @spec lookup(String.t()) :: {:ok, resolved()} | :none
  def lookup(host) do
    host = normalize(host)
    key = host_key(host)

    # Not StoreCache.fetch/4: a hit and a miss need different lifetimes, and
    # fetch takes a single ttl.
    case StoreCache.get(@cache, key) do
      {:hit, :none} ->
        :none

      {:hit, resolved} ->
        {:ok, resolved}

      :miss ->
        case safely(fn -> load_host(host) end) do
          # A read that could not happen is not an answer — caching it would
          # pin the wrong result for the whole TTL after one blip.
          :unavailable ->
            :none

          :none ->
            StoreCache.put(@cache, key, :none, ttl: @miss_ttl)
            :none

          resolved ->
            StoreCache.put(@cache, key, resolved, ttl: @host_ttl)
            {:ok, resolved}
        end
    end
  end

  @doc """
  The store's live, primary custom host, or `nil`.

  `nil` means the store has no custom domain of its own and its canonical URL
  falls back to the platform subdomain or the `/s/:slug` subfolder.
  """
  @spec primary_host(String.t()) :: String.t() | nil
  def primary_host(slug) do
    key = primary_key(slug)

    case StoreCache.get(@cache, key) do
      {:hit, :none} ->
        nil

      {:hit, host} ->
        host

      :miss ->
        case safely(fn -> load_primary_host(slug) end) do
          :unavailable ->
            nil

          :none ->
            StoreCache.put(@cache, key, :none, ttl: @miss_ttl)
            nil

          host ->
            StoreCache.put(@cache, key, host, ttl: @host_ttl)
            host
        end
    end
  end

  @doc "Drops the cached answer for one hostname."
  @spec invalidate(String.t() | nil) :: :ok
  def invalidate(nil), do: :ok
  def invalidate(host), do: StoreCache.invalidate(@cache, host |> normalize() |> host_key())

  @doc "Drops the cached primary host for one store slug."
  @spec invalidate_slug(String.t() | nil) :: :ok
  def invalidate_slug(nil), do: :ok
  def invalidate_slug(slug), do: StoreCache.invalidate(@cache, primary_key(slug))

  @doc """
  Seeds the primary-host cache after a write, so the next canonical render is
  not a cold read during a disconnected LiveView mount.
  """
  @spec warm_slug(String.t() | nil) :: :ok
  def warm_slug(nil), do: :ok

  def warm_slug(slug) do
    case safely(fn -> load_primary_host(slug) end) do
      :unavailable -> :ok
      :none -> StoreCache.put(@cache, primary_key(slug), :none, ttl: @miss_ttl)
      host -> StoreCache.put(@cache, primary_key(slug), host, ttl: @host_ttl)
    end
  end

  defp load_host(host) do
    case Stores.get_store_domain_by_host(host,
           load: [:store],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{store: %{slug: slug}} = domain} ->
        %{
          store_id: domain.store_id,
          slug: slug,
          status: domain.status,
          serve_in_place?: domain.serve_in_place?,
          primary?: domain.primary?
        }

      _ ->
        :none
    end
  end

  defp load_primary_host(slug) do
    case Stores.get_primary_custom_domain_by_slug(slug,
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{host: host}} -> host
      _ -> :none
    end
  end

  # Canonical URLs are rendered on every page, including from callers with no
  # database of their own. Resolving a custom domain turned that into a query,
  # so an unreachable database must degrade to the platform URL rather than
  # take the page down with it.
  defp safely(fun) do
    fun.()
  catch
    :exit, reason ->
      Logger.debug("[domain_resolver] read unavailable: #{inspect(reason)}")
      :unavailable
  rescue
    error ->
      Logger.debug("[domain_resolver] read failed: #{inspect(error)}")
      :unavailable
  end

  defp host_key(host), do: "domain_host:" <> host
  defp primary_key(slug), do: "store_primary_host:" <> to_string(slug)

  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()
end
