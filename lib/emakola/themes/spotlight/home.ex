defmodule Emakola.Themes.Spotlight.Home do
  @moduledoc "Spotlight home — immersive marketing landing that funnels to the hero product page."

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns =
      assigns
      |> assign(:hero_product, List.first(assigns.products))
      |> assign(:hero, get_in(assigns.theme, [:hero]) || %{})
      |> assign(:trust, get_in(assigns.theme, [:trust]) || %{})
      |> assign(:testimonials, get_in(assigns.theme, [:testimonials]) || %{})
      |> assign(:closing, get_in(assigns.theme, [:closing_cta]) || %{})
      |> assign(:ingredients, Emakola.Themes.Spotlight.ingredients())

    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <%!-- HERO --%>
      <section class="relative overflow-hidden">
        <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full spot-blob opacity-60"></div>
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24 grid lg:grid-cols-2 gap-10 items-center relative">
          <div>
            <p class="text-xs uppercase tracking-[0.25em] text-[#7C3AED] font-semibold">
              {Map.get(@hero, :overline, "The one you reach for")}
            </p>
            <h1 class="spot-display text-5xl sm:text-6xl lg:text-7xl text-[#16130F] mt-4 uppercase">
              {if @hero_product, do: @hero_product.title, else: Map.get(@hero, :title, "One product.")}
            </h1>
            <p class="text-[#6B675F] text-base mt-5 max-w-md leading-relaxed">
              {Map.get(@hero, :tagline)}
            </p>
            <div :if={@hero_product} class="mt-7">
              <a
                href={"/s/#{@store.slug}/products/#{@hero_product.slug}"}
                class="inline-block rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider"
              >
                {Map.get(@hero, :cta_text, "Choose yours")}
              </a>
              <p class="text-[11px] uppercase tracking-wider text-[#9b968c] mt-4">
                {Map.get(@hero, :badge, "100% Made in Ghana")}
              </p>
            </div>
            <p :if={!@hero_product} class="mt-7 text-[#6B675F]">
              Our product launches soon — check back shortly.
            </p>
          </div>
          <div class="relative">
            <div class="rounded-3xl overflow-hidden bg-white border border-[#ECE7DE] aspect-[4/5]">
              <.optimized_image
                :if={@hero_product && Shared.first_image(@hero_product)}
                src={Shared.first_image(@hero_product)}
                alt={@hero_product.title}
                class="w-full h-full object-cover"
              />
              <div
                :if={!(@hero_product && Shared.first_image(@hero_product))}
                class="w-full h-full flex items-center justify-center bg-[#F3EFE8]"
              >
                <span class="material-symbols-outlined text-[#d8d0c2] text-6xl">image</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- BENEFITS --%>
      <section
        :if={Shared.section_enabled?(@theme, :why_us)}
        id="benefits"
        phx-hook="ScrollReveal"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
      >
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">
          {Map.get(@trust, :title, "What makes it different")}
        </h2>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-6">
          <div
            :for={item <- Map.get(@trust, :items, [])}
            class="rounded-2xl bg-white border border-[#ECE7DE] p-6 text-center"
          >
            <span class="material-symbols-outlined text-[#7C3AED] text-3xl">
              {Map.get(item, :icon, "star")}
            </span>
            <h3 class="spot-heading text-base font-semibold mt-3">{item.title}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- INGREDIENTS --%>
      <section id="ingredients" phx-hook="ScrollReveal" class="bg-white border-y border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <h2 class="spot-heading text-3xl font-bold mb-10">
            {length(@ingredients)} reasons it works
          </h2>
          <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10 gap-y-8">
            <div :for={ing <- @ingredients} class="border-t border-[#ECE7DE] pt-4">
              <h3 class="spot-heading text-lg font-semibold">{ing.name}</h3>
              <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{ing.description}</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section
        :if={Shared.section_enabled?(@theme, :testimonials)}
        phx-hook="ScrollReveal"
        id="testimonials"
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
      >
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">
          {Map.get(@testimonials, :title, "Loved by everyday people")}
        </h2>
        <div class="grid md:grid-cols-3 gap-6">
          <figure
            :for={t <- Map.get(@testimonials, :items, [])}
            class="rounded-2xl bg-white border border-[#ECE7DE] p-6"
          >
            <div class="text-[#7C3AED]">★★★★★</div>
            <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">"{t.quote}"</blockquote>
            <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">
              {t.name}<span :if={Map.get(t, :location)} class="font-normal"> · {t.location}</span>
            </figcaption>
          </figure>
        </div>
      </section>

      <%!-- STATEMENT / CLOSING CTA --%>
      <section
        :if={Shared.section_enabled?(@theme, :closing_cta)}
        class="bg-[var(--theme-accent-soft)]"
      >
        <div class="max-w-[900px] mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
          <p class="spot-display text-3xl sm:text-4xl text-[#16130F] leading-tight">
            {Map.get(@closing, :title, "One product, done properly.")}
          </p>
          <p class="text-[#6B675F] mt-4">{Map.get(@closing, :subtitle)}</p>
          <a
            :if={@hero_product}
            href={"/s/#{@store.slug}/products/#{@hero_product.slug}"}
            class="inline-block mt-7 rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider"
          >
            {Map.get(@closing, :button_text, "Get yours")}
          </a>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section
        :if={Shared.section_enabled?(@theme, :newsletter)}
        class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center"
      >
        <h2 class="spot-heading text-2xl font-bold">
          {get_in(@theme, [:newsletter, :title]) || "Stay in the loop"}
        </h2>
        <p class="text-sm text-[#6B675F] mt-2">{get_in(@theme, [:newsletter, :subtitle])}</p>
        <form class="flex max-w-md mx-auto mt-6 gap-2">
          <input
            type="email"
            placeholder="you@email.com"
            class="flex-1 px-4 py-3 rounded-full border border-[#ECE7DE] text-sm focus:outline-none focus:border-[#7C3AED]"
          />
          <button type="button" class="rounded-full spot-cta px-6 py-3 text-sm font-semibold">
            {get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}
          </button>
        </form>
      </section>

      <Shared.footer store={@store} />
    </div>
    """
  end
end
