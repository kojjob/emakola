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

  require Logger

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.SEO.Canonical

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
           page_title: page_seo_title(page, store),
           meta_description:
             SEO.meta_description(
               [page_meta_description(page)],
               "#{page.title} from #{store.name}."
             ),
           canonical_url: Canonical.page_url(store, page),
           og_site_name: store.name,
           robots: if(page.blocks == [], do: "noindex, follow", else: "index, follow")
         )}

      :not_found ->
        {:ok,
         socket
         |> put_flash(:error, "Page not found")
         |> redirect(to: store_path(store.slug, "/"))}
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

  defp load_featured_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.load([:images, :variants])
    |> Ash.Query.limit(12)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[page_live] load_featured_products loading featured products raised: #{Exception.message(exception)}"
      )

      []
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  rescue
    exception ->
      Logger.error(
        "[page_live] load_root_categories loading root categories raised: #{Exception.message(exception)}"
      )

      []
  end

  defp page_meta_description(%{meta: meta}) when is_map(meta) do
    Map.get(meta, "description") || Map.get(meta, :description) || ""
  end

  defp page_meta_description(_), do: ""

  defp page_seo_title(%{meta: meta, title: title}, store) when is_map(meta) do
    SEO.meta_title(
      [Map.get(meta, "seo_title"), Map.get(meta, :seo_title)],
      "#{title} - #{store.name}"
    )
  end

  defp page_seo_title(page, store), do: SEO.meta_title([], "#{page.title} - #{store.name}")
end
