defmodule EmakolaWeb.Storefront.AboutLive do
  @moduledoc """
  About page for a store — tells the artisan's story, heritage, and values.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.SEO.Canonical
  alias EmakolaWeb.Storefront.ContentLoader

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    categories = load_root_categories(store)
    page_content = ContentLoader.load(store.id)
    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_content, page_content)
     |> assign(:page_title, "About - #{store.name}")
     |> assign(
       :meta_description,
       SEO.meta_description(
         [
           ContentLoader.field(page_content, :about_intro),
           ContentLoader.field(page_content, :about_story),
           store.description,
           store.tagline
         ],
         "Learn about #{store.name}, its products, and the people behind the store."
       )
     )
     |> assign(:canonical_url, Canonical.path(store, "/about"))
     |> assign(:og_site_name, store.name)
     |> assign(:json_ld, SEO.json_ld_storefront(store))}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :about) do
      {:ok, rendered} -> rendered
      :default -> render_default(assigns)
    end
  end

  # Only reached when the theme implements no :about callback — so this must
  # never call back into the theme. The default About renders inside the
  # store's own chrome via DefaultRenderers.Chrome, like cart and category.
  defp render_default(assigns) do
    Emakola.Themes.DefaultRenderers.About.render(assigns)
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end
end
