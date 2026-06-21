defmodule EmakolaWeb.Storefront.BlogPostLive do
  @moduledoc """
  Premium single blog post page with magazine-style layout,
  reading time, author info, social sharing, and related posts.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.SEO.Canonical

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
              Emakola.Content.increment_post_views!(post, authorize?: false)
            rescue
              _ -> :ok
            end

            {:ok, related} =
              Emakola.Content.Post
              |> Ash.Query.for_read(:list_published, %{
                store_id: store.id,
                type: :blog_post,
                exclude_id: post.id
              })
              |> Ash.Query.limit(3)
              |> Ash.read()

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
             |> assign(:related, related)
             |> assign(:reading_time, reading_time(post.body))
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:categories, [])
             |> assign(:page_title, "#{post.title} - #{store.name}")
             |> assign_article_seo(store, post)}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Post not found")
             |> redirect(to: "/#{slug}/blog")}
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

  defp assign_article_seo(socket, store, post) do
    json_ld = [
      SEO.json_ld_article(post, store),
      SEO.json_ld_breadcrumb([
        %{name: store.name, url: Canonical.store_url(store)},
        %{name: "Blog", url: Canonical.path(store, "/blog")},
        %{name: post.title, url: Canonical.blog_url(store, post)}
      ])
    ]

    socket
    |> assign(:meta_description, post.seo_description || post.excerpt)
    |> assign(:og_image, post.featured_image_url)
    |> assign(:og_type, "article")
    |> assign(:og_site_name, store.name)
    |> assign(:canonical_url, Canonical.blog_url(store, post))
    |> assign(:json_ld, json_ld)
  end

  defp reading_time(nil), do: 1

  defp reading_time(body) do
    word_count = body |> String.split(~r/\s+/) |> length()
    max(div(word_count, 200), 1)
  end
end
