defmodule EmakolaWeb.Storefront.BlogListLive do
  @moduledoc """
  Public blog listing page for a store's published blog posts.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok, posts} =
          Emakola.Content.Post
          |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :blog_post})
          |> Ash.read()

        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0
        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:posts, posts)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:categories, [])
         |> assign(:page_title, "Blog - #{store.name}")}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl font-semibold text-stone-900 mb-8">
        Blog
      </h1>

      <div :if={@posts == []} class="text-center py-16">
        <p class="text-stone-400">No posts yet. Check back soon.</p>
      </div>

      <div class="space-y-8">
        <a :for={post <- @posts} href={"/s/#{@store.slug}/blog/#{post.slug}"} class="block group">
          <article class="flex gap-6">
            <div :if={post.featured_image_url} class="w-48 h-32 rounded-xl overflow-hidden shrink-0">
              <img
                src={post.featured_image_url}
                alt={post.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                loading="lazy"
              />
            </div>
            <div class="flex-1 min-w-0">
              <h2 class="text-lg font-semibold text-stone-900 group-hover:text-amber-700 transition-colors">
                {post.title}
              </h2>
              <p :if={post.excerpt} class="text-sm text-stone-600 mt-1 line-clamp-2">
                {post.excerpt}
              </p>
              <div class="flex items-center gap-3 mt-3 text-xs text-stone-400">
                <span :if={post.published_at}>
                  {Calendar.strftime(post.published_at, "%B %d, %Y")}
                </span>
                <span>{post.view_count} views</span>
              </div>
            </div>
          </article>
        </a>
      </div>
    </div>
    """
  end
end
