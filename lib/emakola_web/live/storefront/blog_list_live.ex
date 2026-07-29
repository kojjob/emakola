defmodule EmakolaWeb.Storefront.BlogListLive do
  @moduledoc """
  Premium blog listing page with hero feature post and card grid.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.SEO.Canonical

  @impl true
  def mount(_params, session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok, posts} =
          Emakola.Content.Post
          |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :blog_post})
          |> Ash.Query.limit(50)
          |> Ash.read()

        cart_session_id = session["cart_session_id"]

        cart_count =
          if connected?(socket) && cart_session_id,
            do: CartStore.cart_count(cart_session_id, store.id),
            else: 0

        {featured, rest} =
          case posts do
            [first | remaining] -> {first, remaining}
            [] -> {nil, []}
          end

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:posts, posts)
         |> assign(:featured, featured)
         |> assign(:rest_posts, rest)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:categories, [])
         |> assign(:page_title, "Blog - #{store.name}")
         |> assign(:meta_description, "Articles and updates from #{store.name}.")
         |> assign(:robots, if(posts == [], do: "noindex, follow", else: "index, follow"))
         |> assign(:canonical_url, Canonical.path(store, "/blog"))}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :blog_list) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.BlogList.render(assigns)
    end
  end
end
