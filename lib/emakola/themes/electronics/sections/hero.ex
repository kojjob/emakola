defmodule Emakola.Themes.Electronics.Sections.Hero do
  @moduledoc """
  Electronics home hero -- extracted verbatim from electronics/home.ex.

  The teal hero band carries Electronics' nav as its first child: the
  translucent header (`bg-[#134E4A]/85`) only reads as a header because it
  sits on the hero's teal. Lifting it out into page chrome would float it
  over the cream body and wash it out, so it stays inside the section it
  was drawn against.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Electronics.Shared

  @impl true
  def key, do: "electronics/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""},
      # The floating spec card. Empty by default and hidden when empty: the
      # theme used to ship "Battery / 40hrs · BT 5.3" to every shop that
      # installed it, which is a checkable fact about goods, stated on behalf
      # of a merchant who never said it and could not withdraw it. Same rule
      # `Emakola.Themes.Terms` already applies to warranties.
      %{key: "spec_label", type: :string, label: "Spec name", default: ""},
      %{key: "spec_value", type: :string, label: "Spec detail", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    custom_title =
      present(setting(assigns[:settings], "heading", get_in(assigns.theme, [:hero, :title])))

    title = custom_title || assigns.store.name

    assigns =
      assigns
      |> assign(:cart_count, assigns[:cart_count] || 0)
      |> assign(:custom_title, custom_title)
      |> assign(:hero_title_first, title_first(title))
      |> assign(:hero_title_second, title_second(title))
      |> assign(
        :hero_subtitle,
        present(
          setting(assigns[:settings], "subheading", get_in(assigns.theme, [:hero, :subtitle]))
        ) || present(Map.get(assigns.store, :description))
      )
      |> assign(
        :hero_cta_text,
        setting(
          assigns[:settings],
          "cta_label",
          get_in(assigns.theme, [:hero, :cta_text]) || "Shop Now"
        )
      )
      |> assign(:hero_image_url, hero_image_url(assigns))
      |> assign(:spec_label, setting(assigns[:settings], "spec_label", nil))
      |> assign(:spec_value, setting(assigns[:settings], "spec_value", nil))

    ~H"""
    <%!-- HERO: split layout, deep teal left, vibrant product right --%>
    <section :if={section_enabled?(@theme, :hero)} class="bg-[#134E4A]">
      <Shared.electronics_nav store={@store} cart_count={@cart_count} on_dark={true} />

      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14 lg:py-20">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class="text-white">
            <%!-- The eyebrow is the store's name over a merchant-written
                 headline. It used to read "New Arrivals" on every shop. --%>
            <span
              :if={@custom_title}
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#0EA5E9]/20 text-[#0EA5E9] text-[11px] font-bold uppercase tracking-[0.18em] mb-5"
            >
              <span class="material-symbols-outlined" style="font-size: 14px;">flash_on</span>
              {@store.name}
            </span>
            <h1 class="electronics-heading text-4xl sm:text-5xl lg:text-6xl font-extrabold leading-[1.05] mb-3">
              {@hero_title_first}
            </h1>
            <p
              :if={@hero_title_second}
              class="electronics-heading text-2xl sm:text-3xl lg:text-4xl text-[#0EA5E9] font-bold mb-6"
            >
              {@hero_title_second}
            </p>
            <p :if={@hero_subtitle} class="text-base text-white/75 leading-relaxed mb-8 max-w-md">
              {@hero_subtitle}
            </p>
            <div class="flex flex-col sm:flex-row gap-3">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-white text-[#134E4A] text-sm font-bold hover:bg-[#F5EFE5] transition-colors min-h-[48px]"
              >
                {@hero_cta_text}
                <span class="material-symbols-outlined" style="font-size: 18px;">
                  arrow_forward
                </span>
              </a>
              <a
                href={store_path(@store.slug, "/about")}
                class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-white/20 text-white text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
              >
                Learn more
              </a>
            </div>
          </div>

          <div class="relative">
            <div class="aspect-square rounded-3xl overflow-hidden bg-gradient-to-br from-[#1A6E69] to-[#0E3F3B] flex items-center justify-center">
              <%= if @hero_image_url do %>
                <img
                  src={@hero_image_url}
                  alt={"#{@store.name} storefront"}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <span class="material-symbols-outlined text-[#0EA5E9]/40" style="font-size: 200px;">
                  headphones
                </span>
              <% end %>
            </div>
            <%!--
              Floating spec card — the merchant's own words or nothing. The
              detail is what makes the card worth showing, so a label with no
              detail behind it does not render.
            --%>
            <div
              :if={@spec_value}
              class="absolute bottom-6 left-6 sm:bottom-8 sm:left-8 bg-white rounded-2xl px-5 py-4 shadow-xl"
            >
              <p
                :if={@spec_label}
                class="text-[10px] uppercase tracking-wider text-[#6B7280] font-semibold mb-1"
              >
                {@spec_label}
              </p>
              <p class="electronics-mono text-base font-bold text-[#134E4A]">{@spec_value}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # The hero shows only a picture the merchant chose for it — the theme's
  # hero images or the store's cover. It never borrows a product photograph:
  # the featured deal card below carries that photo, and a home must not show
  # the same picture twice. A shop with no hero image keeps the glyph.
  #
  # Every candidate goes through ImageUrl, so a page link pasted into a picture
  # field cannot put a broken image at the top of a storefront.
  defp hero_image_url(assigns) do
    theme_images = get_in(assigns.theme, [:hero, :images]) || []

    Emakola.Stores.ImageUrl.first_image(
      theme_images ++
        [get_in(assigns.theme, [:hero, :image_url]), Map.get(assigns.store, :cover_image_url)]
    )
  end

  # Splits the hero title at the first comma so the headline can be
  # "Upgrade Your Gear" then sky-blue "Upgrade Yourself" on a second line.
  defp title_first(title) when is_binary(title) do
    case String.split(title, ",", parts: 2) do
      [first, _] -> String.trim(first)
      [single] -> single
    end
  end

  # The second headline line only exists when the title contains a comma
  # ("Upgrade Your Gear, Upgrade Yourself") — never append copy of our own.
  defp title_second(title) when is_binary(title) do
    case String.split(title, ",", parts: 2) do
      [_, second] -> String.trim(second)
      _ -> nil
    end
  end
end
