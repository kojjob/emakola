defmodule EmakolaWeb.Storefront.BlogListLive do
  @moduledoc """
  Premium blog listing page with hero feature post and card grid.
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
         |> assign(:page_title, "Blog - #{store.name}")}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :blog_list) do
      {:ok, rendered} -> rendered
      :default -> render_default(assigns)
    end
  end

  defp render_default(assigns) do
    ~H"""
    <div class="bg-stone-50">
      <%!-- Hero Header --%>
      <div class="bg-stone-900 text-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <div class="lg:flex lg:items-end lg:justify-between lg:gap-16">
            <div class="max-w-2xl mb-8 lg:mb-0">
              <p class="text-amber-400 text-sm font-semibold tracking-widest uppercase mb-3">
                {@store.name}
              </p>
              <h1 class="font-[Cormorant,Georgia,serif] text-4xl sm:text-5xl lg:text-6xl font-bold leading-tight mb-3">
                Stories & Ideas
              </h1>
              <p class="text-stone-400 text-lg leading-relaxed">
                Discover the stories, tips, and inspiration behind what we do.
              </p>
            </div>
            <div class="lg:w-96 shrink-0">
              <p class="font-[Cormorant,Georgia,serif] text-xl font-semibold text-white mb-3">
                Stay in the loop
              </p>
              <div class="flex gap-2">
                <input
                  type="email"
                  placeholder="Enter your email"
                  class="flex-1 bg-stone-800 border border-stone-700 rounded-xl px-4 py-3 text-sm text-white placeholder:text-stone-500 focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500"
                />
                <button class="cursor-pointer px-5 py-3 bg-amber-600 text-white rounded-xl text-sm font-semibold hover:bg-amber-700 transition-colors shrink-0">
                  Subscribe
                </button>
              </div>
              <p class="text-xs text-stone-500 mt-2">No spam. Unsubscribe anytime.</p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Featured Post (Hero Card) --%>
        <div :if={@featured} class="mt-8 sm:mt-10 mb-8 sm:mb-10">
          <a
            href={"/s/#{@store.slug}/blog/#{@featured.slug}"}
            class="cursor-pointer group block bg-white rounded-2xl shadow-xl shadow-stone-900/5 overflow-hidden lg:grid lg:grid-cols-2"
          >
            <div class="aspect-[16/10] lg:aspect-[4/3] overflow-hidden">
              <img
                :if={@featured.featured_image_url}
                src={@featured.featured_image_url}
                alt={@featured.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
              />
              <div
                :if={!@featured.featured_image_url}
                class="w-full h-full bg-gradient-to-br from-amber-100 to-stone-200 flex items-center justify-center"
              >
                <svg
                  class="w-16 h-16 text-stone-300"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Z"
                  />
                </svg>
              </div>
            </div>
            <div class="p-6 sm:p-8 lg:p-10 flex flex-col justify-center">
              <div class="flex items-center gap-3 mb-4">
                <span class="px-3 py-1 bg-amber-100 text-amber-800 text-xs font-semibold rounded-full uppercase tracking-wide">
                  Featured
                </span>
                <span class="text-xs text-stone-400">
                  {reading_time(@featured.body)} min read
                </span>
              </div>
              <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl lg:text-4xl font-bold text-stone-900 mb-3 group-hover:text-amber-700 transition-colors">
                {@featured.title}
              </h2>
              <p :if={@featured.excerpt} class="text-stone-600 leading-relaxed mb-5 line-clamp-3">
                {@featured.excerpt}
              </p>
              <div class="flex items-center gap-4">
                <div class="w-10 h-10 rounded-full bg-amber-600 flex items-center justify-center text-white font-bold text-sm">
                  {String.first(@store.name)}
                </div>
                <div>
                  <p class="text-sm font-semibold text-stone-900">{@store.name}</p>
                  <p :if={@featured.published_at} class="text-xs text-stone-400">
                    {Calendar.strftime(@featured.published_at, "%B %d, %Y")}
                  </p>
                </div>
              </div>
            </div>
          </a>
        </div>

        <%!-- Section Header --%>
        <div :if={@rest_posts != []} class="mb-6">
          <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold text-stone-900">
            Latest Posts
          </h2>
        </div>

        <%!-- Post Grid --%>
        <div
          :if={@rest_posts != []}
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8 mb-10"
        >
          <a
            :for={post <- @rest_posts}
            href={"/s/#{@store.slug}/blog/#{post.slug}"}
            class="cursor-pointer group block bg-white rounded-2xl shadow-sm hover:shadow-lg transition-shadow duration-300 overflow-hidden"
          >
            <div class="aspect-[16/10] overflow-hidden">
              <img
                :if={post.featured_image_url}
                src={post.featured_image_url}
                alt={post.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                loading="lazy"
              />
              <div
                :if={!post.featured_image_url}
                class="w-full h-full bg-gradient-to-br from-stone-100 to-stone-200 flex items-center justify-center"
              >
                <svg
                  class="w-10 h-10 text-stone-300"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Z"
                  />
                </svg>
              </div>
            </div>
            <div class="p-5 sm:p-6">
              <div class="flex items-center gap-2 mb-3">
                <span
                  :if={post.tags != []}
                  class="text-xs font-semibold text-amber-700 uppercase tracking-wide"
                >
                  {List.first(post.tags)}
                </span>
                <span class="text-stone-300">|</span>
                <span class="text-xs text-stone-400">{reading_time(post.body)} min read</span>
              </div>
              <h3 class="font-[Cormorant,Georgia,serif] text-xl sm:text-2xl font-bold text-stone-900 mb-2 group-hover:text-amber-700 transition-colors leading-snug">
                {post.title}
              </h3>
              <p :if={post.excerpt} class="text-sm text-stone-500 line-clamp-2 leading-relaxed">
                {post.excerpt}
              </p>
              <div class="flex items-center justify-between mt-4 pt-4 border-t border-stone-100">
                <p :if={post.published_at} class="text-xs text-stone-400">
                  {Calendar.strftime(post.published_at, "%b %d, %Y")}
                </p>
                <span class="text-xs text-stone-400 flex items-center gap-1">
                  <svg
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
                    />
                  </svg>
                  {post.view_count}
                </span>
              </div>
            </div>
          </a>
        </div>

        <%!-- Empty State --%>
        <div :if={@posts == []} class="text-center py-16 sm:py-20">
          <svg
            class="w-16 h-16 text-stone-300 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            stroke-width="1"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25"
            />
          </svg>
          <h2 class="font-[Cormorant,Georgia,serif] text-2xl font-semibold text-stone-900 mb-2">
            Coming soon
          </h2>
          <p class="text-stone-500">
            We're working on some great content. Check back soon!
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp reading_time(nil), do: 1

  defp reading_time(body) do
    word_count = body |> String.split(~r/\s+/) |> length()
    max(div(word_count, 200), 1)
  end
end
