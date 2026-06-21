defmodule Emakola.Themes.Akoma.Home do
  @moduledoc "Akoma home page — minimal hero, featured grid, trust, newsletter."

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akoma.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns =
      assigns
      |> assign(:hero, get_in(assigns.theme, [:hero]) || %{})
      |> assign_new(:featured_products, fn -> Enum.take(Map.get(assigns, :products, []), 8) end)

    ~H"""
    <div class="akoma-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <%!-- Hero --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24 text-center">
        <h1 class="akoma-heading text-4xl sm:text-6xl font-extrabold text-[#1A1A1A] leading-[1.05]">
          {Map.get(@hero, :title, "Considered goods,")}
          <span class="block text-[#2F5D50]">{Map.get(@hero, :subtitle, "made to last.")}</span>
        </h1>
        <a
          href={store_path(@store.slug, "/products")}
          class="inline-block mt-8 px-8 py-3.5 rounded-md bg-[#1A1A1A] text-white text-sm font-semibold uppercase tracking-wider hover:bg-[#2F5D50] transition-colors"
        >
          {Map.get(@hero, :cta_text, "Shop the collection")}
        </a>
      </section>

      <%!-- Featured --%>
      <section
        :if={section_enabled?(@theme, :featured_products) and @featured_products != []}
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10"
      >
        <div class="flex items-baseline justify-between mb-6">
          <h2 class="akoma-heading text-xl font-bold text-[#1A1A1A]">Featured</h2>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-sm text-[#2F5D50] hover:underline"
          >
            View all →
          </a>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card
            :for={product <- @featured_products}
            product={product}
            store={@store}
          />
        </div>
      </section>

      <%!-- Trust --%>
      <section
        :if={section_enabled?(@theme, :why_us)}
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 border-t border-[#E8EAE7]"
      >
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
          <div :for={item <- get_in(@theme, [:trust, :items]) || []}>
            <h3 class="akoma-heading text-base font-semibold text-[#1A1A1A]">{item.title}</h3>
            <p class="text-sm text-[#6B7280] mt-1">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- Closing CTA --%>
      <section
        :if={section_enabled?(@theme, :closing_cta)}
        class="bg-[#2F5D50] py-14 sm:py-20 text-center"
      >
        <div class="max-w-[640px] mx-auto px-4 sm:px-6">
          <h2 class="akoma-heading text-2xl sm:text-3xl font-bold text-white">
            {get_in(@theme, [:closing_cta, :title]) || "Find your next favourite thing"}
          </h2>
          <p class="text-sm text-[#C8DDD7] mt-3">
            {get_in(@theme, [:closing_cta, :subtitle]) || "Thoughtfully made products, fairly priced."}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-block mt-8 px-8 py-3.5 rounded-md bg-white text-[#2F5D50] text-sm font-semibold uppercase tracking-wider hover:bg-[#F8F9F7] transition-colors"
          >
            {get_in(@theme, [:closing_cta, :button_text]) || "Browse all"}
          </a>
        </div>
      </section>

      <%!-- Newsletter --%>
      <section
        :if={section_enabled?(@theme, :newsletter)}
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 text-center"
      >
        <h2 class="akoma-heading text-2xl font-bold text-[#1A1A1A]">
          {get_in(@theme, [:newsletter, :title]) || "Join the list"}
        </h2>
        <p class="text-sm text-[#6B7280] mt-2">{get_in(@theme, [:newsletter, :subtitle])}</p>
        <form class="flex max-w-md mx-auto mt-6 gap-2">
          <input
            type="email"
            placeholder="you@email.com"
            class="flex-1 px-4 py-3 rounded-md border border-[#E8EAE7] text-sm focus:outline-none focus:border-[#2F5D50]"
          />
          <button
            type="button"
            class="px-6 py-3 rounded-md bg-[#1A1A1A] text-white text-sm font-semibold"
          >
            {get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}
          </button>
        </form>
      </section>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end

  defp section_enabled?(theme, key) do
    case get_in(theme, [:sections, key]) do
      false -> false
      _ -> true
    end
  end
end
