defmodule Emakola.Themes.Akoma.Home do
  @moduledoc "Akoma home page — minimal hero, featured grid, trust, newsletter."

  use Phoenix.Component

  alias Emakola.Themes.Akoma.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :featured_products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns = assign(assigns, :hero, get_in(assigns.theme, [:hero]) || %{})

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
          href={"/s/#{@store.slug}/products"}
          class="inline-block mt-8 px-8 py-3.5 rounded-md bg-[#1A1A1A] text-white text-sm font-semibold uppercase tracking-wider hover:bg-[#2F5D50] transition-colors"
        >
          {Map.get(@hero, :cta_text, "Shop the collection")}
        </a>
      </section>

      <%!-- Featured --%>
      <section
        :if={@featured_products != []}
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10"
      >
        <div class="flex items-baseline justify-between mb-6">
          <h2 class="akoma-heading text-xl font-bold text-[#1A1A1A]">Featured</h2>
          <a href={"/s/#{@store.slug}/products"} class="text-sm text-[#2F5D50] hover:underline">
            View all →
          </a>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card
            :for={product <- Enum.take(@featured_products, 8)}
            product={product}
            store={@store}
          />
        </div>
      </section>

      <%!-- Trust --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 border-t border-[#E8EAE7]">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
          <div :for={item <- get_in(@theme, [:trust, :items]) || []}>
            <h3 class="akoma-heading text-base font-semibold text-[#1A1A1A]">{item.title}</h3>
            <p class="text-sm text-[#6B7280] mt-1">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- Newsletter --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 text-center">
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
end
