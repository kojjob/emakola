defmodule EmakolaWeb.Storefront.PageLive do
  @moduledoc """
  Storefront route for merchant-built custom pages.

  URL: `/s/:store_slug/p/:page_slug`

  Loads the published page via `Emakola.Pages.fetch_published_page/2`
  and renders it through `Emakola.PageBuilder.Renderer`. Drafts and
  unknown slugs 404 (redirect home).

  Featured products are loaded once so any `product_grid` block in
  the page can reference them.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(%{"page_slug" => page_slug}, _session, socket) do
    store = socket.assigns[:store]

    case Emakola.Pages.fetch_published_page(store, page_slug) do
      {:ok, page} ->
        products = load_featured_products(store)
        categories = load_root_categories(store)

        {:ok,
         socket
         |> assign(
           page: page,
           products: products,
           categories: categories,
           page_title: "#{page.title} - #{store.name}",
           meta_description: page_meta_description(page)
         )}

      :not_found ->
        {:ok,
         socket
         |> put_flash(:error, "Page not found")
         |> redirect(to: "/@#{store.slug}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-50">
      <Emakola.PageBuilder.Renderer.page
        page={@page}
        store={@store}
        products={@products}
        categories={@categories}
      />
    </div>
    """
  end

  defp load_featured_products(nil), do: []

  defp load_featured_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.load([:images, :variants])
    |> Ash.Query.limit(12)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_root_categories(nil), do: []

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  rescue
    _ -> []
  end

  defp page_meta_description(%{meta: meta}) when is_map(meta) do
    Map.get(meta, "description") || Map.get(meta, :description) || ""
  end

  defp page_meta_description(_), do: ""
end
