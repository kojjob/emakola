defmodule Emakola.Themes.Atelier.About do
  @moduledoc """
  Atelier theme About page — Stitch design reference.

  Sections:
  - Hero with store name and tagline
  - Heritage / Mission statement
  - Craftsmanship process (3-step visual)
  - Store values (icon grid)
  - Call to action
  """
  use Phoenix.Component

  alias Emakola.Themes.Atelier.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
        transparent={true}
      />

      <%!-- Hero Section (extra top padding to account for transparent navbar) --%>
      <section
        class="relative overflow-hidden -mt-16 sm:-mt-20"
        style="background: var(--theme-accent);"
      >
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-32 sm:pt-44 pb-20 sm:pb-32">
          <div class="max-w-3xl">
            <span class="text-xs font-semibold uppercase tracking-[0.2em] text-white/60 mb-4 block">
              Our Story
            </span>
            <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black text-white leading-[1.1] mb-6">
              Preserving Heritage.<br />
              <span class="italic" style="color: var(--theme-primary-light, #22C55E);">
                Crafting the Future.
              </span>
            </h1>
            <p class="text-lg sm:text-xl text-white/80 leading-relaxed max-w-2xl">
              {if @store.description,
                do: @store.description,
                else:
                  "We believe in the power of artisan craft to connect communities, preserve traditions, and create beauty that transcends borders."}
            </p>
          </div>
        </div>
        <%!-- Decorative pattern --%>
        <div class="absolute top-0 right-0 w-1/3 h-full opacity-10">
          <svg viewBox="0 0 400 600" fill="none" class="w-full h-full">
            <pattern id="kente" x="0" y="0" width="80" height="80" patternUnits="userSpaceOnUse">
              <rect width="80" height="80" fill="none" />
              <rect x="0" y="0" width="40" height="40" fill="white" opacity="0.3" />
              <rect x="40" y="40" width="40" height="40" fill="white" opacity="0.3" />
              <line x1="0" y1="20" x2="80" y2="20" stroke="white" stroke-width="2" opacity="0.2" />
              <line x1="0" y1="60" x2="80" y2="60" stroke="white" stroke-width="2" opacity="0.2" />
            </pattern>
            <rect width="400" height="600" fill="url(#kente)" />
          </svg>
        </div>
      </section>

      <%!-- Heritage / Mission Section --%>
      <section class="py-16 sm:py-24 bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="atelier-about-2col">
            <div>
              <span
                class="text-xs font-semibold uppercase tracking-[0.2em] mb-3 block"
                style="color: var(--theme-primary);"
              >
                Heritage & Mission
              </span>
              <h2 class="text-3xl sm:text-4xl font-black text-gray-900 leading-tight mb-6">
                Every Thread Tells a Story
              </h2>
              <div class="space-y-4 text-gray-600 leading-relaxed">
                <p>
                  For generations, West African artisans have woven stories into fabric, carved wisdom into wood, and shaped beauty from the earth beneath their feet. Their craft is more than technique - it is a living conversation between past and present.
                </p>
                <p>
                  {@store.name} was founded to ensure these traditions not only survive but flourish. We partner directly with master artisans, providing fair prices and global reach while preserving the authenticity that makes each piece extraordinary.
                </p>
              </div>
            </div>
            <div class="rounded-2xl overflow-hidden bg-gray-100 aspect-[4/5]">
              <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-gray-100 to-gray-200">
                <span
                  class="text-8xl font-black opacity-20"
                  style="color: var(--theme-accent);"
                >
                  {String.first(@store.name)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Craftsmanship Process --%>
      <section class="py-16 sm:py-24 bg-gray-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12 sm:mb-16">
            <span
              class="text-xs font-semibold uppercase tracking-[0.2em] mb-3 block"
              style="color: var(--theme-primary);"
            >
              The Process
            </span>
            <h2 class="text-3xl sm:text-4xl font-black text-gray-900">
              From Artisan Hands to Yours
            </h2>
          </div>

          <div class="atelier-about-3col">
            <.process_step
              number="01"
              title="Sourced with Intention"
              description="We work directly with artisan communities across Ghana and West Africa, selecting master craftspeople whose work embodies generations of skill and cultural significance."
              icon="search"
            />
            <.process_step
              number="02"
              title="Crafted with Care"
              description="Each piece is handmade using traditional techniques passed down through generations. Natural materials, organic dyes, and time-honored methods ensure unmatched quality."
              icon="hands"
            />
            <.process_step
              number="03"
              title="Delivered with Pride"
              description="Every order is carefully inspected, beautifully packaged, and shipped with a certificate of authenticity. Your purchase directly supports the artisan who created it."
              icon="package"
            />
          </div>
        </div>
      </section>

      <%!-- Values Section --%>
      <section class="py-16 sm:py-24 bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12 sm:mb-16">
            <span
              class="text-xs font-semibold uppercase tracking-[0.2em] mb-3 block"
              style="color: var(--theme-primary);"
            >
              What We Stand For
            </span>
            <h2 class="text-3xl sm:text-4xl font-black text-gray-900">
              Our Values
            </h2>
          </div>

          <div class="atelier-about-4col">
            <.value_card
              icon="shield"
              title="Authenticity"
              description="Every piece is verified authentic, handcrafted by skilled artisans using traditional methods."
            />
            <.value_card
              icon="heart"
              title="Fair Trade"
              description="Artisans receive fair compensation. Your purchase directly supports families and communities."
            />
            <.value_card
              icon="leaf"
              title="Sustainability"
              description="Natural materials, organic dyes, and eco-conscious practices protect our shared environment."
            />
            <.value_card
              icon="globe"
              title="Cultural Preservation"
              description="We document and celebrate the stories, techniques, and heritage behind every creation."
            />
          </div>
        </div>
      </section>

      <%!-- CTA Section --%>
      <section style="background: var(--theme-accent);">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 text-center">
          <h2 class="text-3xl sm:text-4xl font-black text-white mb-4">
            Ready to Discover?
          </h2>
          <p class="text-white/70 text-lg mb-8 max-w-xl mx-auto">
            Explore our curated collection of handcrafted pieces, each with a story waiting to be told.
          </p>
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              Shop the Collection
            </a>
            <a
              :if={Map.get(@store, :whatsapp_number)}
              href={"https://wa.me/#{@store.whatsapp_number}?text=#{URI.encode("Hi! I'd love to learn more about your products.")}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg border-2 border-white/30 text-white hover:bg-white/10 transition-all duration-300 min-h-[48px]"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
              </svg>
              Chat with Us
            </a>
          </div>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Process Step Card ──

  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true

  defp process_step(assigns) do
    ~H"""
    <div class="text-center">
      <div
        class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-5"
        style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
      >
        <.step_icon name={@icon} />
      </div>
      <span
        class="text-xs font-bold tracking-widest mb-2 block"
        style="color: var(--theme-primary);"
      >
        {@number}
      </span>
      <h3 class="text-lg font-bold text-gray-900 mb-3">{@title}</h3>
      <p class="text-sm text-gray-600 leading-relaxed">{@description}</p>
    </div>
    """
  end

  # ── Value Card ──

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp value_card(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-xl p-6 sm:p-8 text-center hover:shadow-md transition-shadow duration-300">
      <div
        class="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4"
        style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
      >
        <.value_icon name={@icon} />
      </div>
      <h3 class="text-base font-bold text-gray-900 mb-2">{@title}</h3>
      <p class="text-sm text-gray-600 leading-relaxed">{@description}</p>
    </div>
    """
  end

  # ── Icons ──

  defp step_icon(%{name: "search"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
    """
  end

  defp step_icon(%{name: "hands"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M18 11V6a2 2 0 00-2-2 2 2 0 00-2 2v0M14 10V4a2 2 0 00-2-2 2 2 0 00-2 2v2M10 10.5V6a2 2 0 00-2-2 2 2 0 00-2 2v8" />
      <path d="M18 8a2 2 0 012 2v7.21a4 4 0 01-.86 2.48L16.5 23H8l-4.33-6A3 3 0 014.6 13.4L6 12" />
    </svg>
    """
  end

  defp step_icon(%{name: "package"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M16.5 9.4l-9-5.19M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" /><line x1="12" y1="22.08" x2="12" y2="12" />
    </svg>
    """
  end

  defp step_icon(assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
    </svg>
    """
  end

  defp value_icon(%{name: "shield"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <polyline points="9 12 11 14 15 10" />
    </svg>
    """
  end

  defp value_icon(%{name: "heart"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
    </svg>
    """
  end

  defp value_icon(%{name: "leaf"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M17 8C8 10 5.9 16.17 3.82 21.34l1.89.66.95-2.3c.48.17.98.3 1.34.3C19 20 22 3 22 3c-1 2-8 2.25-13 3.25S2 11.5 2 13.5s1.75 3.75 1.75 3.75" />
    </svg>
    """
  end

  defp value_icon(%{name: "globe"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
      <line x1="2" y1="12" x2="22" y2="12" />
      <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z" />
    </svg>
    """
  end

  defp value_icon(assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
    </svg>
    """
  end
end
