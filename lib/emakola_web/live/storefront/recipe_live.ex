defmodule EmakolaWeb.Storefront.RecipeLive do
  @moduledoc """
  Single recipe page for the storefront.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "recipe_slug" => recipe_slug}, session, socket) do
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
              post |> Ash.Changeset.for_update(:increment_views) |> Ash.update()
            rescue
              _ -> :ok
            end

            recipe_meta = load_recipe_meta(post.id)

            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:post, post)
             |> assign(:safe_body, Emakola.Content.HtmlSafe.sanitize(post.body))
             |> assign(:recipe_meta, recipe_meta)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:categories, [])
             |> assign(:page_title, "#{post.title} - #{store.name}")}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Recipe not found")
             |> redirect(to: "/s/#{slug}/recipes")}
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

  defp load_recipe_meta(post_id) do
    case Emakola.Content.RecipeMeta
         |> Ash.Query.for_read(:get_by_post, %{post_id: post_id})
         |> Ash.read(authorize?: false) do
      {:ok, [meta | _]} -> meta
      _ -> nil
    end
  end
end
