defmodule Emakola.Themes.DefaultRenderers.RecipeList do
  @moduledoc """
  Default render for the storefront recipe list page.

  Used by `EmakolaWeb.Storefront.RecipeListLive` when no theme overrides
  `:render_recipe_list`. See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl font-semibold text-stone-900 mb-8">
        Recipes
      </h1>

      <div :if={@posts == []} class="text-center py-16">
        <p class="text-stone-400">No recipes yet. Check back soon.</p>
      </div>

      <div class="grid gap-6 sm:grid-cols-2">
        <a :for={post <- @posts} href={"/s/#{@store.slug}/recipes/#{post.slug}"} class="block group">
          <article class="rounded-xl overflow-hidden border border-stone-200 hover:border-stone-300 transition-colors">
            <div :if={post.featured_image_url} class="aspect-[4/3] overflow-hidden">
              <img
                src={post.featured_image_url}
                alt={post.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                loading="lazy"
              />
            </div>
            <div class="p-4">
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
