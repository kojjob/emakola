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
             |> Ash.read_one() do
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
      :default -> render_default(assigns)
    end
  end

  defp render_default(assigns) do
    ~H"""
    <article class="max-w-3xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <a
        href={"/s/#{@store.slug}/recipes"}
        class="inline-flex items-center gap-1 text-sm text-stone-500 hover:text-stone-700 mb-6"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
        </svg>
        Back to recipes
      </a>

      <header class="mb-8">
        <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl font-semibold text-stone-900 mb-3">
          {@post.title}
        </h1>
        <div class="flex flex-wrap items-center gap-3 text-sm text-stone-500">
          <span :if={@post.published_at}>
            {Calendar.strftime(@post.published_at, "%B %d, %Y")}
          </span>
          <span :if={@recipe_meta && @recipe_meta.prep_time}>
            Prep: {@recipe_meta.prep_time} min
          </span>
          <span :if={@recipe_meta && @recipe_meta.cook_time}>
            Cook: {@recipe_meta.cook_time} min
          </span>
          <span :if={@recipe_meta && @recipe_meta.servings}>
            Serves {@recipe_meta.servings}
          </span>
          <span
            :if={@recipe_meta && @recipe_meta.difficulty}
            class="px-2 py-0.5 bg-stone-100 rounded-full text-xs font-medium capitalize"
          >
            {@recipe_meta.difficulty}
          </span>
        </div>
      </header>

      <div :if={@post.featured_image_url} class="mb-8 rounded-2xl overflow-hidden">
        <img src={@post.featured_image_url} alt={@post.title} class="w-full" />
      </div>

      <div
        :if={@recipe_meta && @recipe_meta.ingredients != []}
        class="mb-8 bg-stone-50 rounded-2xl p-6"
      >
        <h2 class="text-xl font-semibold text-stone-900 mb-4">Ingredients</h2>
        <ul class="space-y-2">
          <li
            :for={ingredient <- @recipe_meta.ingredients}
            class="flex items-start gap-3 text-stone-700"
          >
            <span class="w-1.5 h-1.5 rounded-full bg-amber-500 mt-2.5 shrink-0"></span>
            <span>
              <strong>{ingredient["quantity"]}</strong> {ingredient["item"]}
            </span>
          </li>
        </ul>
      </div>

      <div :if={@recipe_meta && @recipe_meta.instructions != []} class="mb-8">
        <h2 class="text-xl font-semibold text-stone-900 mb-4">Instructions</h2>
        <ol class="space-y-4">
          <li
            :for={{step, idx} <- Enum.with_index(@recipe_meta.instructions, 1)}
            class="flex gap-4"
          >
            <span class="w-7 h-7 rounded-full bg-amber-600 text-white flex items-center justify-center text-sm font-bold shrink-0 mt-0.5">
              {idx}
            </span>
            <p class="text-stone-700 flex-1">{step}</p>
          </li>
        </ol>
      </div>

      <div class="prose prose-stone prose-lg max-w-none">
        {raw(@post.body)}
      </div>

      <div :if={@post.tags != []} class="mt-8 flex gap-2">
        <span
          :for={tag <- @post.tags}
          class="px-3 py-1 bg-stone-100 rounded-full text-sm text-stone-600"
        >
          {tag}
        </span>
      </div>
    </article>
    """
  end

  defp load_recipe_meta(post_id) do
    case Emakola.Content.RecipeMeta
         |> Ash.Query.for_read(:get_by_post, %{post_id: post_id})
         |> Ash.read() do
      {:ok, [meta | _]} -> meta
      _ -> nil
    end
  end
end
