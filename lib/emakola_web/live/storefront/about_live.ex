defmodule EmakolaWeb.Storefront.AboutLive do
  @moduledoc """
  About page for a store — tells the artisan's story, heritage, and values.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        categories = load_root_categories(store)
        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:categories, categories)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:page_title, "About - #{store.name}")
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
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
