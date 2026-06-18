defmodule EmakolaWeb.Storefront.RecipeListLive do
  @moduledoc """
  Public recipe listing page for a store's published recipes.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok, posts} =
          Emakola.Content.Post
          |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :recipe})
          |> Ash.Query.limit(50)
          |> Ash.read()

        cart_session_id = session["cart_session_id"]

        cart_count =
          if connected?(socket) && cart_session_id,
            do: CartStore.cart_count(cart_session_id, store.id),
            else: 0

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:posts, posts)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:categories, [])
         |> assign(:page_title, "Recipes - #{store.name}")}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :recipe_list) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.RecipeList.render(assigns)
    end
  end
end
