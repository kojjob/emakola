defmodule EmakolaWeb.Storefront.FaqLive do
  @moduledoc """
  FAQ page for a store — renders the merchant's own question/answer pairs.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Storefront.ContentLoader

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:categories, Emakola.Catalog.list_root_categories!(store.id))
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_content, ContentLoader.load(store.id))
     |> assign(:page_title, "FAQ - #{store.name}")}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :faq) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Faq.render(assigns)
    end
  end
end
