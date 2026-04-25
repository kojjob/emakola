defmodule Emakola.Themes.Atlas.Home do
  @moduledoc """
  Atlas theme home page — sidebar-driven catalog browsing.

  Layout (desktop):
    [sidebar 240px] [main content]

  Sections:
    * Hero — full-bleed lifestyle shot with arrow nav + dual CTA
    * What's New — 2-up large card pair (Constructor X pattern)
    * Bestsellers — 3-up card grid with color-coded pill prices
    * From the feed — 4-up Instagram strip
    * Newsletter — "Sign up and save 10%"
    * Footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Atlas.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:whats_new_products, fn -> Enum.take(assigns.products, 2) end)
      |> assign_new(:bestseller_products, fn ->
        assigns.products |> Enum.drop(2) |> Enum.take(6)
      end)
      |> assign_new(:feed_products, fn -> Enum.take(assigns.products, 4) end)
      |> assign_new(:hero_title, fn -> hero_title(assigns) end)
      |> assign_new(:hero_subtitle, fn -> hero_subtitle(assigns) end)
      |> assign_new(:hero_image, fn -> hero_image(assigns) end)

    ~H"""
    <div class="min-h-screen bg-[#FAFAFA] text-[#0F172A]">
      <Shared.theme_styles theme={@theme} />
      <Shared.atlas_nav store={@store} categories={@categories} cart_count={@cart_count} />

      <div class="flex">
        <Shared.sidebar store={@store} categories={@categories} />

        <div class="flex-1 min-w-0">
          <main class="max-w-[1100px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-10">
            <%!-- Breadcrumb / store name ── --%>
            <div
              class="flex items-center gap-2 mb-6 text-sm text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
            >
              <span class="material-symbols-outlined text-[18px]">store</span>
              <span class="text-[#0F172A] font-medium">{@store.name}</span>
            </div>

            <%!-- Hero ── --%>
            <section :if={section_enabled?(@theme, :hero)} class="mb-10">
              <div class="relative aspect-[16/7] rounded-2xl overflow-hidden bg-[#0F172A]">
                <%= if @hero_image do %>
                  <.optimized_image
                    src={@hero_image}
                    alt={"#{@store.name} — #{@hero_title}"}
                    priority={:high}
                    class="w-full h-full object-cover"
                  />
                  <div class="absolute inset-0 bg-gradient-to-r from-[#0F172A]/65 via-[#0F172A]/30 to-transparent">
                  </div>
                <% else %>
                  <div class="absolute inset-0 bg-gradient-to-br from-[#1E293B] to-[#0F172A]"></div>
                <% end %>
                <div class="absolute inset-0 flex items-center justify-center text-center px-6">
                  <div class="max-w-xl">
                    <h1
                      class="text-3xl sm:text-4xl lg:text-5xl font-bold text-white leading-tight mb-3"
                      style="font-family: 'Inter', sans-serif;"
                    >
                      {@hero_title}
                    </h1>
                    <p
                      class="text-sm sm:text-base text-white/85 mb-5"
                      style="font-family: 'Inter', sans-serif;"
                    >
                      {@hero_subtitle}
                    </p>
                    <div class="flex flex-wrap gap-2 justify-center">
                      <a
                        href={"/s/#{@store.slug}/products"}
                        class="inline-flex items-center px-5 py-2 rounded-full bg-white text-[#0F172A] text-sm font-medium hover:bg-[#F1F5F9] transition-colors"
                        style="font-family: 'Inter', sans-serif;"
                      >
                        Shop now
                      </a>
                      <a
                        href={"/s/#{@store.slug}/products"}
                        class="inline-flex items-center px-5 py-2 rounded-full text-white border border-white/40 text-sm font-medium hover:bg-white/10 transition-colors"
                        style="font-family: 'Inter', sans-serif;"
                      >
                        Explore catalog
                      </a>
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  class="hidden sm:inline-flex absolute left-3 top-1/2 -translate-y-1/2 w-9 h-9 rounded-full bg-white/90 text-[#0F172A] items-center justify-center hover:bg-white transition-colors shadow"
                  aria-label="Previous"
                >
                  <span class="material-symbols-outlined text-[20px]">chevron_left</span>
                </button>
                <button
                  type="button"
                  class="hidden sm:inline-flex absolute right-3 top-1/2 -translate-y-1/2 w-9 h-9 rounded-full bg-white/90 text-[#0F172A] items-center justify-center hover:bg-white transition-colors shadow"
                  aria-label="Next"
                >
                  <span class="material-symbols-outlined text-[20px]">chevron_right</span>
                </button>
              </div>
            </section>

            <%!-- What's New (2-up) ── --%>
            <section
              :if={section_enabled?(@theme, :whats_new) and @whats_new_products != []}
              class="mb-10"
              aria-labelledby="atlas-whats-new"
            >
              <div class="flex items-center justify-between mb-4">
                <h2
                  id="atlas-whats-new"
                  class="text-lg font-bold text-[#0F172A] flex items-center gap-2"
                  style="font-family: 'Inter', sans-serif;"
                >
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)]">
                    new_releases
                  </span>
                  What's new
                </h2>
                <div class="flex gap-1">
                  <button
                    type="button"
                    class="w-8 h-8 rounded-full bg-white border border-[#E2E8F0] text-[#64748B] inline-flex items-center justify-center hover:text-[#0F172A] transition-colors"
                    aria-label="Previous"
                  >
                    <span class="material-symbols-outlined text-[18px]">chevron_left</span>
                  </button>
                  <button
                    type="button"
                    class="w-8 h-8 rounded-full bg-white border border-[#E2E8F0] text-[#64748B] inline-flex items-center justify-center hover:text-[#0F172A] transition-colors"
                    aria-label="Next"
                  >
                    <span class="material-symbols-outlined text-[18px]">chevron_right</span>
                  </button>
                </div>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Shared.shelf_card
                  :for={{product, idx} <- Enum.with_index(@whats_new_products)}
                  product={product}
                  store={@store}
                  color_index={idx}
                  swatches={["#0F172A", "#475569", "#10B981", "#0EA5E9"]}
                />
              </div>
            </section>

            <%!-- Bestsellers ── --%>
            <section
              :if={section_enabled?(@theme, :bestsellers) and @bestseller_products != []}
              class="mb-10"
              aria-labelledby="atlas-bestsellers"
            >
              <div class="flex items-center justify-between mb-4">
                <h2
                  id="atlas-bestsellers"
                  class="text-lg font-bold text-[#0F172A] flex items-center gap-2"
                  style="font-family: 'Inter', sans-serif;"
                >
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)]">
                    trending_up
                  </span>
                  Bestsellers
                </h2>
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="text-xs text-[var(--theme-accent,#2563EB)] hover:underline"
                  style="font-family: 'Inter', sans-serif;"
                >
                  View all →
                </a>
              </div>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-4">
                <Shared.shelf_card
                  :for={{product, idx} <- Enum.with_index(@bestseller_products)}
                  product={product}
                  store={@store}
                  color_index={idx + 2}
                  swatches={["#0F172A", "#475569", "#0EA5E9"]}
                />
              </div>
            </section>

            <%!-- From the feed (Instagram strip) ── --%>
            <section
              :if={section_enabled?(@theme, :feed) and @feed_products != []}
              class="mb-10"
              aria-labelledby="atlas-feed"
            >
              <div class="flex items-center justify-between mb-4">
                <h2
                  id="atlas-feed"
                  class="text-lg font-bold text-[#0F172A] flex items-center gap-2"
                  style="font-family: 'Inter', sans-serif;"
                >
                  <span class="material-symbols-outlined text-[20px] text-[var(--theme-accent,#2563EB)]">
                    tag
                  </span>
                  From the feed
                </h2>
                <a
                  href="#"
                  class="text-xs text-[var(--theme-accent,#2563EB)] hover:underline"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Follow us →
                </a>
              </div>
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <.feed_tile
                  :for={product <- @feed_products}
                  product={product}
                  store={@store}
                />
              </div>
            </section>

            <%!-- Newsletter ── --%>
            <section
              :if={section_enabled?(@theme, :newsletter)}
              class="mb-10 text-center py-8 border-t border-[#E2E8F0]"
            >
              <p
                class="text-sm text-[#64748B] mb-3"
                style="font-family: 'Inter', sans-serif;"
              >
                Sign up for the newsletter and get 10% off your first order
              </p>
              <form
                class="flex justify-center gap-0 max-w-md mx-auto bg-white rounded-full border border-[#E2E8F0] overflow-hidden"
                phx-submit="subscribe_newsletter"
              >
                <input
                  type="email"
                  name="email"
                  placeholder="Email Address"
                  required
                  class="flex-1 px-4 py-2.5 bg-transparent border-0 focus:outline-none focus:ring-0 text-sm text-[#0F172A] placeholder:text-[#94A3B8]"
                  style="font-family: 'Inter', sans-serif;"
                />
                <button
                  type="submit"
                  class="px-5 py-2.5 bg-[var(--theme-accent,#2563EB)] text-white text-sm font-medium hover:bg-[#1D4ED8] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Send
                </button>
              </form>
            </section>
          </main>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Feed tile ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  defp feed_tile(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group relative aspect-square rounded-lg overflow-hidden bg-[#F1F5F9]"
    >
      <.optimized_image
        :if={@image}
        src={@image}
        alt={@product.title}
        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
      />
      <div :if={!@image} class="w-full h-full flex items-center justify-center">
        <span class="material-symbols-outlined text-4xl text-[#CBD5E1]">photo_camera</span>
      </div>
      <div class="absolute inset-0 bg-[#0F172A]/0 group-hover:bg-[#0F172A]/30 transition-colors duration-300 flex items-center justify-center opacity-0 group-hover:opacity-100">
        <span class="material-symbols-outlined text-white text-3xl">favorite_border</span>
      </div>
    </a>
    """
  end

  # ── Helpers ──

  defp hero_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "New Styles Are Here"
    end
  end

  defp hero_subtitle(assigns) do
    case get_in(assigns, [:theme, :hero, :subtitle]) do
      sub when is_binary(sub) and sub != "" -> sub
      _ -> "Discover the latest premium pieces in our collections"
    end
  end

  defp hero_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp section_enabled?(theme, section_name) do
    case theme do
      %{sections: sections} when is_map(sections) ->
        Map.get(sections, section_name, true)

      _ ->
        true
    end
  end
end
