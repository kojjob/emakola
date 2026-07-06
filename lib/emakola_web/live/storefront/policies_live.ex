defmodule EmakolaWeb.Storefront.PoliciesLive do
  @moduledoc """
  Policies page for a store — a single page with anchored shipping/returns,
  privacy and terms sections.
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
     |> assign(:page_title, "Policies - #{store.name}")}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :policies) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Policies.render(assigns)
    end
  end
end
