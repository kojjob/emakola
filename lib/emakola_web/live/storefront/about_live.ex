defmodule EmakolaWeb.Storefront.AboutLive do
  @moduledoc """
  About page for a store — tells the artisan's story, heritage, and values.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    categories = load_root_categories(store)
    cart_session_id = session["cart_session_id"]
    cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_title, "About - #{store.name}")}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :about) do
      {:ok, rendered} -> rendered
      :default -> render_default(assigns)
    end
  end

  defp render_default(assigns) do
    assigns.theme_module.render_about(assigns)
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end
end
