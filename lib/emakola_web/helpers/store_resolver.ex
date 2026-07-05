defmodule EmakolaWeb.Helpers.StoreResolver do
  @moduledoc """
  Resolves a store from its URL slug.

  Used by all storefront LiveViews in mount/3 to load the store
  from the :store_slug path parameter.
  """

  alias Emakola.Stores.Store

  @doc """
  Looks up a store by its slug and classifies it by lifecycle status:

    * `{:ok, store}` — the store is publicly live (`Store.live?/1`: the
      merchant has it open AND the platform has not suspended/blocked it).
    * `{:error, :unavailable}` — the store exists but is not live (suspended,
      blocked, or the merchant has closed it). Callers should show a neutral
      "store unavailable" page; the reason is never exposed publicly.
    * `{:error, :not_found}` — the slug matches no store, OR the store is
      archived. Archived stores are hidden as if they never existed.

  Storefront LiveViews mount under the `ResolveStore` on_mount hook, which
  halts non-live stores before their `mount/3` runs — so only the hook and
  non-LiveView callers (e.g. the sitemap/feed controllers) need to handle the
  `:unavailable` value.
  """
  @spec resolve(String.t()) :: {:ok, Store.t()} | {:error, :not_found | :unavailable}
  def resolve(slug) when is_binary(slug) do
    case Emakola.Stores.get_store_by_slug(slug, authorize?: false) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, store} ->
        cond do
          Store.live?(store) -> {:ok, store}
          store.status == :archived -> {:error, :not_found}
          true -> {:error, :unavailable}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end
end
