defmodule EmakolaWeb.Storefront.BlogPostLive do
  @moduledoc """
  Premium single blog post page with magazine-style layout,
  reading time, author info, social sharing, and related posts.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "post_slug" => post_slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case Emakola.Content.Post
             |> Ash.Query.for_read(:get_by_slug, %{
               slug: post_slug,
               store_id: store.id,
               type: :blog_post
             })
             |> Ash.read(authorize?: false) do
          {:ok, [post | _]} ->
            try do
              post |> Ash.Changeset.for_update(:increment_views) |> Ash.update()
            rescue
              _ -> :ok
            end

            {:ok, related} =
              Emakola.Content.Post
              |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :blog_post})
              |> Ash.Query.filter(id != ^post.id)
              |> Ash.Query.limit(3)
              |> Ash.read()

            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:post, post)
             |> assign(:safe_body, Emakola.Content.HtmlSafe.sanitize(post.body))
             |> assign(:related, related)
             |> assign(:reading_time, reading_time(post.body))
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:categories, [])
             |> assign(:page_title, "#{post.title} - #{store.name}")}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Post not found")
             |> redirect(to: "/s/#{slug}/blog")}
        end

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :blog_post) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.BlogPost.render(assigns)
    end
  end

  defp reading_time(nil), do: 1

  defp reading_time(body) do
    word_count = body |> String.split(~r/\s+/) |> length()
    max(div(word_count, 200), 1)
  end
end
