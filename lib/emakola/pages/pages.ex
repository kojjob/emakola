defmodule Emakola.Pages do
  @moduledoc """
  The Pages domain — backing store for the merchant page builder.

  Distinct from `Emakola.Content` (blog posts, recipes, media) because pages
  are block-based, edited via the page-builder LiveView, and override theme
  rendering when published. Posts are markdown-bodied editorial content.

  ## Public API

      Emakola.Pages.fetch_published_page(store, "home")
      Emakola.Pages.list_pages_for_store(store_id)
      Emakola.Pages.create_page(attrs)
  """

  use Ash.Domain

  alias Emakola.Pages.Page

  resources do
    resource Page do
      define(:create_page, action: :create)
      define(:update_page, action: :update)
      define(:list_pages_for_store, action: :list_for_store, args: [:store_id])

      define(:get_published_page,
        action: :get_published_for_store,
        args: [:store_id, :slug]
      )
    end
  end

  @doc """
  Fetches the published page at `slug` for `store`. Returns `{:ok, page}` if a
  published page exists, `:not_found` otherwise.

  Used by `StoreLive` to decide whether to render via the page builder or
  fall through to the active theme's home renderer.

  Bypasses authorization: storefront reads always succeed for publicly
  available pages.
  """
  @spec fetch_published_page(map() | nil, String.t()) :: {:ok, struct()} | :not_found
  def fetch_published_page(nil, _slug), do: :not_found

  def fetch_published_page(%{id: store_id}, slug) when is_binary(slug) do
    case get_published_page(store_id, slug, authorize?: false) do
      {:ok, page} -> {:ok, page}
      _ -> :not_found
    end
  end

  def fetch_published_page(_, _), do: :not_found
end
