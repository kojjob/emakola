defmodule Emakola.Themes.Vibrant.Sections.Hero do
  @moduledoc """
  Vibrant home hero — the editorial signboard, and the page's only `<h1>`.

  Full-bleed merchant photo when one is configured, amber-gradient wax-print
  panel when not, with the store-name chip, headline, subhead and the dual CTA
  (shop + WhatsApp).

  Copy resolution is layered so nothing moves for a store that never opened the
  editor: a section setting wins, else the theme's `hero.*` config (the old
  theme customiser), else the legacy fallback. Same for the image.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Vibrant.Shared

  @impl true
  def key, do: "vibrant/hero"

  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Shop the collection"},
      %{key: "image_url", type: :image_url, label: "Hero image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    settings = assigns[:settings] || %{}

    assigns =
      assigns
      |> assign(:enabled, Shared.section_enabled?(assigns.theme, :hero))
      |> assign(:hero_title, present(settings["headline"]) || theme_title(assigns))
      |> assign(:hero_subtitle, present(settings["subheadline"]) || theme_subtitle(assigns))
      |> assign(:hero_image, present(settings["image_url"]) || theme_image(assigns))
      |> assign(:cta_label, present(settings["cta_label"]) || "Shop the collection")

    ~H"""
    <section :if={@enabled} class="relative overflow-hidden">
      <%= if @hero_image do %>
        <div class="relative aspect-[4/5] sm:aspect-[16/9] lg:aspect-[21/9] max-h-[80vh]">
          <.optimized_image
            src={@hero_image}
            alt={"#{@store.name} hero"}
            priority={:high}
            class="absolute inset-0 w-full h-full object-cover"
          />
          <div class="absolute inset-0 bg-gradient-to-t from-[#1C1917]/85 via-[#1C1917]/40 to-transparent">
          </div>
          <.hero_content
            store={@store}
            title={@hero_title}
            subtitle={@hero_subtitle}
            cta_label={@cta_label}
          />
        </div>
      <% else %>
        <div class="relative bg-gradient-to-br from-[var(--theme-primary,#B45309)] via-[#D97706] to-[var(--theme-highlight,#F59E0B)] py-20 sm:py-24 lg:py-32">
          <div class="absolute inset-0 opacity-15" aria-hidden="true">
            <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern
                  id="vibrant-pattern"
                  x="0"
                  y="0"
                  width="40"
                  height="40"
                  patternUnits="userSpaceOnUse"
                >
                  <circle cx="20" cy="20" r="6" fill="white" fill-opacity="0.4" />
                  <path
                    d="M0 20 L40 20 M20 0 L20 40"
                    stroke="white"
                    stroke-width="0.5"
                    stroke-opacity="0.3"
                  />
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#vibrant-pattern)" />
            </svg>
          </div>
          <.hero_content
            store={@store}
            title={@hero_title}
            subtitle={@hero_subtitle}
            cta_label={@cta_label}
          />
        </div>
      <% end %>
    </section>
    """
  end

  # ── Hero Content (shared between image and gradient variants) ──

  attr :store, :map, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :cta_label, :string, required: true

  defp hero_content(assigns) do
    ~H"""
    <div class="absolute inset-0 flex items-end sm:items-center">
      <div class="relative w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
        <div class="max-w-2xl">
          <span class="inline-flex items-center px-3 py-1.5 text-[11px] font-bold tracking-[0.2em] uppercase text-white bg-white/15 rounded-full mb-4 backdrop-blur-sm border border-white/20">
            {@store.name}
          </span>
          <h1
            class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.05] mb-4"
            style="font-family: 'Manrope', sans-serif;"
          >
            {@title}
          </h1>
          <p
            class="text-base sm:text-lg text-white/85 leading-relaxed mb-7 max-w-lg"
            style="font-family: 'Inter', sans-serif;"
          >
            {@subtitle}
          </p>
          <div class="flex flex-wrap gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center gap-2 px-7 py-3.5 bg-white text-[#1C1917] rounded-full text-sm sm:text-base font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
              style="font-family: 'Inter', sans-serif;"
            >
              {@cta_label}
              <svg
                class="w-4 h-4 sm:w-5 sm:h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
            <a
              :if={Map.get(@store, :whatsapp_number)}
              href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 px-6 py-3.5 bg-white/10 text-white rounded-full text-sm sm:text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/30"
              style="font-family: 'Inter', sans-serif;"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
              </svg>
              Chat with us
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp theme_title(assigns) do
    case get_in(assigns, [:theme, :hero, :title]) do
      title when is_binary(title) and title != "" -> title
      _ -> "Discover #{assigns.store.name}"
    end
  end

  defp theme_subtitle(assigns) do
    cond do
      title = get_in(assigns, [:theme, :hero, :subtitle]) ->
        if title != "", do: title, else: store_subtitle(assigns)

      true ->
        store_subtitle(assigns)
    end
  end

  defp store_subtitle(%{store: %{description: desc}}) when is_binary(desc) and desc != "",
    do: desc

  # Was "Hand-picked pieces from our latest collection. Crafted with care, ready
  # to ship." — who selected the goods and how they were made, written for a
  # merchant who had not filled in their store description.
  defp store_subtitle(%{store: %{name: name}}), do: "Shop the collection at #{name}."

  defp theme_image(assigns) do
    case get_in(assigns, [:theme, :hero, :image_url]) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
