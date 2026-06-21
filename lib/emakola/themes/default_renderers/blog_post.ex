defmodule Emakola.Themes.DefaultRenderers.BlogPost do
  @moduledoc """
  Default render for the storefront single-blog-post page.

  Used by `EmakolaWeb.Storefront.BlogPostLive` when no theme overrides
  `:blog_post`. The merchant-authored body is sanitized in the
  LiveView's `mount/3` and passed in via `@safe_body` — this module
  does not touch raw HTML.

  See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  def render(assigns) do
    ~H"""
    <Emakola.Themes.Atelier.Shared.navbar
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="blog"
    />

    <div>
      <%!-- Hero Image --%>
      <div
        :if={@post.featured_image_url}
        class="relative h-[40vh] sm:h-[50vh] lg:h-[60vh] overflow-hidden"
      >
        <img src={@post.featured_image_url} alt={@post.title} class="w-full h-full object-cover" />
        <div class="absolute inset-0 bg-gradient-to-t from-stone-900/80 via-stone-900/20 to-transparent">
        </div>
        <div class="absolute bottom-0 left-0 right-0 p-6 sm:p-10 lg:p-16">
          <div class="max-w-3xl mx-auto">
            <a
              href={store_path(@store.slug, "/blog")}
              class="cursor-pointer inline-flex items-center gap-1.5 text-sm text-white/70 hover:text-white transition-colors mb-4"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
              Back to blog
            </a>
            <div class="flex items-center gap-3 mb-4">
              <span
                :if={@post.tags != []}
                class="px-3 py-1 bg-amber-500/90 text-white text-xs font-semibold rounded-full uppercase tracking-wide"
              >
                {List.first(@post.tags)}
              </span>
              <span class="text-white/60 text-sm">{@reading_time} min read</span>
            </div>
            <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl lg:text-5xl font-bold text-white leading-tight">
              {@post.title}
            </h1>
          </div>
        </div>
      </div>

      <%!-- No-image header fallback --%>
      <div :if={!@post.featured_image_url} class="bg-stone-900 py-16 sm:py-20">
        <div class="max-w-3xl mx-auto px-4 sm:px-6">
          <a
            href={store_path(@store.slug, "/blog")}
            class="cursor-pointer inline-flex items-center gap-1.5 text-sm text-stone-400 hover:text-white transition-colors mb-6"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
            Back to blog
          </a>
          <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl lg:text-5xl font-bold text-white leading-tight">
            {@post.title}
          </h1>
        </div>
      </div>

      <%!-- Article Meta Bar --%>
      <div class="border-b border-stone-100">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 py-5 flex flex-wrap items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-amber-600 flex items-center justify-center text-white font-bold text-sm">
              {String.first(@store.name)}
            </div>
            <div>
              <p class="text-sm font-semibold text-stone-900">{@store.name}</p>
              <p :if={@post.published_at} class="text-xs text-stone-400">
                {Calendar.strftime(@post.published_at, "%B %d, %Y")}
              </p>
            </div>
          </div>
          <%!-- Share Buttons --%>
          <div class="flex items-center gap-2">
            <span class="text-xs text-stone-400 mr-1 hidden sm:inline">Share</span>
            <a
              href={"https://wa.me/?text=#{URI.encode(@post.title <> " — " <> current_url(assigns))}"}
              target="_blank"
              rel="noopener"
              class="cursor-pointer w-9 h-9 rounded-full bg-stone-100 hover:bg-whatsapp hover:text-white flex items-center justify-center text-stone-500 transition-colors"
              title="Share on WhatsApp"
            >
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
              </svg>
            </a>
            <a
              href={"https://twitter.com/intent/tweet?text=#{URI.encode(@post.title)}&url=#{URI.encode(current_url(assigns))}"}
              target="_blank"
              rel="noopener"
              class="cursor-pointer w-9 h-9 rounded-full bg-stone-100 hover:bg-stone-900 hover:text-white flex items-center justify-center text-stone-500 transition-colors"
              title="Share on X"
            >
              <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            </a>
            <a
              href={"https://www.facebook.com/sharer/sharer.php?u=#{URI.encode(current_url(assigns))}"}
              target="_blank"
              rel="noopener"
              class="cursor-pointer w-9 h-9 rounded-full bg-stone-100 hover:bg-[#1877F2] hover:text-white flex items-center justify-center text-stone-500 transition-colors"
              title="Share on Facebook"
            >
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
              </svg>
            </a>
          </div>
        </div>
      </div>

      <%!-- Article Body --%>
      <article class="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <p :if={@post.excerpt} class="text-xl text-stone-600 leading-relaxed mb-10 font-light">
          {@post.excerpt}
        </p>

        <div class="prose prose-lg prose-stone max-w-none prose-headings:font-[Cormorant,Georgia,serif] prose-headings:font-bold prose-a:text-amber-700 prose-a:no-underline hover:prose-a:underline prose-img:rounded-2xl prose-blockquote:border-amber-500 prose-blockquote:bg-amber-50/50 prose-blockquote:rounded-xl prose-blockquote:py-1">
          {@safe_body}
        </div>

        <%!-- Tags --%>
        <div :if={@post.tags != []} class="mt-12 pt-8 border-t border-stone-200">
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-sm text-stone-500 mr-1">Topics:</span>
            <span
              :for={tag <- @post.tags}
              class="px-3 py-1.5 bg-stone-100 hover:bg-stone-200 rounded-full text-sm text-stone-600 transition-colors cursor-pointer"
            >
              {tag}
            </span>
          </div>
        </div>

        <%!-- Author Card --%>
        <div class="mt-10 p-6 sm:p-8 bg-stone-50 rounded-2xl">
          <div class="flex items-start gap-4">
            <div class="w-14 h-14 rounded-full bg-amber-600 flex items-center justify-center text-white font-bold text-lg shrink-0">
              {String.first(@store.name)}
            </div>
            <div>
              <p class="font-semibold text-stone-900 mb-1">Written by {@store.name}</p>
              <p
                :if={@store.description}
                class="text-sm text-stone-500 leading-relaxed line-clamp-2"
              >
                {@store.description}
              </p>
              <a
                href={store_path(@store.slug, "/blog")}
                class="cursor-pointer inline-flex items-center gap-1 text-sm text-amber-700 font-medium mt-3 hover:text-amber-800"
              >
                View all posts
                <svg
                  class="w-3.5 h-3.5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </article>

      <%!-- Related Posts --%>
      <div :if={@related != []} class="bg-stone-50 py-14 sm:py-20">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-bold text-stone-900 mb-8 text-center">
            You might also enjoy
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
            <a
              :for={rp <- @related}
              href={store_path(@store.slug, "/blog/#{rp.slug}")}
              class="cursor-pointer group block bg-white rounded-2xl shadow-sm hover:shadow-lg transition-shadow duration-300 overflow-hidden"
            >
              <div class="aspect-[16/10] overflow-hidden">
                <img
                  :if={rp.featured_image_url}
                  src={rp.featured_image_url}
                  alt={rp.title}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  loading="lazy"
                />
                <div
                  :if={!rp.featured_image_url}
                  class="w-full h-full bg-gradient-to-br from-stone-100 to-stone-200"
                >
                </div>
              </div>
              <div class="p-5">
                <p class="text-xs text-stone-400 mb-2">
                  {if rp.published_at, do: Calendar.strftime(rp.published_at, "%b %d, %Y"), else: ""}
                </p>
                <h3 class="font-[Cormorant,Georgia,serif] text-xl font-bold text-stone-900 group-hover:text-amber-700 transition-colors leading-snug">
                  {rp.title}
                </h3>
              </div>
            </a>
          </div>
        </div>
      </div>

      <%!-- Newsletter CTA --%>
      <div class="bg-stone-900 py-14 sm:py-16">
        <div class="max-w-xl mx-auto px-4 sm:px-6 text-center">
          <h3 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-bold text-white mb-3">
            Enjoyed this article?
          </h3>
          <p class="text-stone-400 mb-6">
            Subscribe for more recipes, cooking tips, and stories from {@store.name}.
          </p>
          <div class="flex flex-col sm:flex-row gap-3">
            <input
              type="email"
              placeholder="Enter your email"
              class="flex-1 bg-stone-800 border border-stone-700 rounded-xl px-4 py-3.5 text-sm text-white placeholder:text-stone-500 focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500"
            />
            <button class="cursor-pointer px-6 py-3.5 bg-amber-600 text-white rounded-xl text-sm font-semibold hover:bg-amber-700 transition-colors shrink-0">
              Subscribe
            </button>
          </div>
        </div>
      </div>
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    """
  end

  defp current_url(assigns) do
    "#{EmakolaWeb.Endpoint.url()}/s/#{assigns.store.slug}/blog/#{assigns.post.slug}"
  end
end
