defmodule EmakolaWeb.PlatformBlogLive do
  @moduledoc """
  The Makola blog index at makola.io/blog — platform-level posts (nil
  store_id) written for merchant acquisition SEO. Newest post leads as an
  editorial feature; the rest flow into a card grid.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    posts = Emakola.Content.list_platform_published_posts!()

    {featured, rest} =
      case posts do
        [first | remaining] -> {first, remaining}
        [] -> {nil, []}
      end

    {:ok,
     assign(socket,
       posts: posts,
       featured: featured,
       rest_posts: rest,
       page_title: "Blog — Makola | Guides for Selling Online in Ghana",
       meta_description:
         "Practical guides for Ghanaian merchants: selling online, accepting MoMo payments, WhatsApp commerce, and growing your store with Makola.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/blog"),
       robots: if(posts == [], do: "noindex, follow", else: "index, follow"),
       json_ld:
         EmakolaWeb.Helpers.SEO.json_ld_breadcrumb([
           %{name: "Home", url: url(~p"/")},
           %{name: "Blog", url: url(~p"/blog")}
         ])
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen bg-white font-body antialiased">
        <.landing_nav />
        <main class="pt-16">
          <section class="py-16 lg:py-20 px-4">
            <div class="max-w-6xl mx-auto">
              <p class="text-xs font-semibold tracking-[0.2em] uppercase text-[#d4a843] mb-3">
                The Makola blog
              </p>
              <h1 class="text-3xl lg:text-5xl font-headline font-bold text-[#0c1526] max-w-3xl">
                Guides for selling online in Ghana
              </h1>
              <p class="text-base text-[#5f6b7a] mt-4 max-w-2xl">
                Mobile money, WhatsApp orders, and building a store customers trust —
                written for merchants, not for tech people.
              </p>
            </div>
          </section>

          <section :if={@featured == nil} class="pb-24 px-4">
            <div class="max-w-6xl mx-auto rounded-xl bg-[#f7f8fa] p-12 text-center">
              <p class="text-lg font-semibold text-[#0c1526]">No posts yet</p>
              <p class="text-sm text-[#5f6b7a] mt-2">
                Guides are on the way. Meanwhile, see <.link
                  navigate={~p"/how-it-works"}
                  class="text-[#2563eb] font-medium"
                >
                  how Makola works
                </.link>.
              </p>
            </div>
          </section>

          <section :if={@featured} class="pb-16 px-4">
            <div class="max-w-6xl mx-auto">
              <.link
                navigate={~p"/blog/#{@featured.slug}"}
                class="group grid grid-cols-1 lg:grid-cols-2 gap-8 items-center rounded-2xl bg-[#f7f8fa] overflow-hidden"
              >
                <img
                  :if={@featured.featured_image_url}
                  src={@featured.featured_image_url}
                  alt={@featured.title}
                  class="w-full aspect-[4/3] lg:aspect-auto lg:h-full object-cover"
                />
                <div class="p-8 lg:p-10">
                  <div class="h-px w-10 bg-[#d4a843] mb-4"></div>
                  <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] group-hover:text-[#2563eb] transition-colors">
                    {@featured.title}
                  </h2>
                  <p class="text-base text-[#5f6b7a] mt-3">{@featured.excerpt}</p>
                  <p class="text-sm text-[#0c1526] font-medium mt-6">
                    Read the guide <span aria-hidden="true" class="text-[#2563eb]">&rarr;</span>
                  </p>
                </div>
              </.link>
            </div>
          </section>

          <section :if={@rest_posts != []} class="pb-24 px-4">
            <div class="max-w-6xl mx-auto grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              <.link
                :for={post <- @rest_posts}
                navigate={~p"/blog/#{post.slug}"}
                class="group rounded-xl overflow-hidden bg-white border border-[#e5e8ee] hover:shadow-md transition-shadow"
              >
                <img
                  :if={post.featured_image_url}
                  src={post.featured_image_url}
                  alt={post.title}
                  loading="lazy"
                  class="w-full aspect-[16/9] object-cover"
                />
                <div class="p-6">
                  <h3 class="text-lg font-headline font-semibold text-[#0c1526] group-hover:text-[#2563eb] transition-colors">
                    {post.title}
                  </h3>
                  <p class="text-sm text-[#5f6b7a] mt-2 line-clamp-3">{post.excerpt}</p>
                </div>
              </.link>
            </div>
          </section>
        </main>
        <.landing_footer />
      </div>
    </Layouts.app>
    """
  end
end
