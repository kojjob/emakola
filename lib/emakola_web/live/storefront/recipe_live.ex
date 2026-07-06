defmodule EmakolaWeb.Storefront.RecipeLive do
  @moduledoc """
  Single recipe page for the storefront.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Storefront.Path

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.SEO.Canonical

  @impl true
  def mount(%{"recipe_slug" => recipe_slug}, session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case Emakola.Content.Post
             |> Ash.Query.for_read(:get_by_slug, %{
               slug: recipe_slug,
               store_id: store.id,
               type: :recipe
             })
             |> Ash.read_one(authorize?: false) do
          {:ok, %{} = post} ->
            try do
              Emakola.Content.increment_post_views!(post, authorize?: false)
            rescue
              _ -> :ok
            end

            recipe_meta = load_recipe_meta(post.id)

            cart_session_id = session["cart_session_id"]

            cart_count =
              if connected?(socket) && cart_session_id,
                do: CartStore.cart_count(cart_session_id, store.id),
                else: 0

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:post, post)
             |> assign(:safe_body, Emakola.Content.HtmlSafe.sanitize(post.body))
             |> assign(:recipe_meta, recipe_meta)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:categories, [])
             |> assign(:page_title, "#{post.title} - #{store.name}")
             |> assign_recipe_seo(store, post, recipe_meta)}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Recipe not found")
             |> redirect(to: store_path(slug, "/recipes"))}
        end

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :recipe_detail) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.RecipeDetail.render(assigns)
    end
  end

  defp assign_recipe_seo(socket, store, post, recipe_meta) do
    post_with_meta = Map.put(post, :recipe_meta, recipe_meta)

    json_ld = [
      SEO.json_ld_recipe(post_with_meta, store),
      SEO.json_ld_breadcrumb([
        %{name: store.name, url: Canonical.store_url(store)},
        %{name: "Recipes", url: Canonical.path(store, "/recipes")},
        %{name: post.title, url: Canonical.recipe_url(store, post)}
      ])
    ]

    socket
    |> assign(:meta_description, post.seo_description || post.excerpt)
    |> assign(:og_image, post.featured_image_url)
    |> assign(:og_type, "article")
    |> assign(:og_site_name, store.name)
    |> assign(:canonical_url, Canonical.recipe_url(store, post))
    |> assign(:json_ld, json_ld)
  end

  defp load_recipe_meta(post_id) do
    case Emakola.Content.get_recipe_meta_by_post(post_id, authorize?: false) do
      {:ok, [meta | _]} -> meta
      _ -> nil
    end
  end
end
