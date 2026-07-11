defmodule Emakola.Themes.Atelier.Sections.Hero do
  @moduledoc "Atelier home hero -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Atelier.{Home, Shared}

  @impl true
  def key, do: "atelier/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = prepare_hero_assigns(assigns)

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :hero)}
      class="relative min-h-screen flex items-end overflow-hidden -mt-16 sm:-mt-20"
    >
      <%!-- Background: images with Ken Burns, or solid gradient fallback --%>
      <div class="absolute inset-0 overflow-hidden" style="clip-path: inset(0);">
        <%= if @has_images do %>
          <%!-- Carousel — smooth crossfade with subtle Ken Burns zoom --%>
          <%= if @use_carousel do %>
            <% # Each slide owns (100 / N)% of the timeline.
            # Fade overlap = 4% so there is NEVER a blank frame.
            pct = Float.round(100.0 / @image_count, 2)
            overlap = 4.0 %>
            <style>
              @keyframes atelier-slide {
                0%                                 { opacity: 0; transform: scale(1); }
                <%= overlap %>%                    { opacity: 1; transform: scale(1.005); }
                <%= Float.round(pct - overlap, 1) %>% { opacity: 1; transform: scale(1.04); }
                <%= pct %>%                        { opacity: 0; transform: scale(1.04); }
                100%                               { opacity: 0; transform: scale(1); }
              }
              .atelier-hero-img {
                will-change: opacity, transform;
                animation: atelier-slide <%= @total_duration %>s ease-in-out infinite;
              }
              @keyframes atelier-progress {
                0%   { transform: scaleX(0); transform-origin: left; }
                92%  { transform: scaleX(1); transform-origin: left; }
                100% { transform: scaleX(1); transform-origin: left; }
              }
            </style>
            <.optimized_image
              :for={{url, idx} <- Enum.with_index(@valid_images)}
              src={url}
              alt={"#{@store.name} collection #{idx + 1}"}
              priority={if idx == 0, do: :high, else: :auto}
              class="atelier-hero-img absolute inset-0 w-full h-full object-cover object-center"
              style={"animation-delay: #{Float.round(idx * @total_duration / @image_count - (if idx > 0, do: @total_duration * overlap / 100, else: 0), 1)}s; opacity: #{if idx == 0, do: 1, else: 0};"}
            />
          <% else %>
            <%!-- Single image: gentle Ken Burns drift --%>
            <.optimized_image
              src={List.first(@valid_images)}
              alt={"#{@store.name} collection"}
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover object-center"
              style="animation: kb-single 20s ease-in-out infinite alternate;"
            />
            <style>
              @keyframes kb-single {
                0%   { transform: scale(1)    translate(0, 0); }
                100% { transform: scale(1.06) translate(-1%, -0.5%); }
              }
            </style>
          <% end %>

          <%!-- Scrim: two-layer overlay guarantees text contrast on ANY image --%>
          <div class="absolute inset-0 bg-black/30"></div>
          <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/30 to-transparent">
          </div>
        <% else %>
          <%!-- Gradient fallback when no valid hero images exist --%>
          <div
            class="absolute inset-0"
            style="background: linear-gradient(135deg, #1C1917 0%, #292524 40%, #44403C 70%, #B45309 100%);"
          >
          </div>
          <%!-- Subtle pattern overlay for visual texture --%>
          <div
            class="absolute inset-0 opacity-10"
            style="background-image: radial-gradient(circle at 25% 25%, white 1px, transparent 1px), radial-gradient(circle at 75% 75%, white 1px, transparent 1px); background-size: 60px 60px;"
          >
          </div>
        <% end %>
      </div>

      <%!-- Content --%>
      <div
        class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full pb-16 sm:pb-24 pt-32"
        style="text-shadow: 0 1px 3px rgba(0,0,0,0.4);"
      >
        <div class="max-w-3xl">
          <%!-- Badge --%>
          <span
            class="inline-block px-4 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 text-white"
            style="background: var(--theme-accent, #166534); text-shadow: none;"
          >
            {@hero_subtitle}
          </span>

          <%!-- Heading --%>
          <h1
            class="text-5xl sm:text-6xl md:text-7xl lg:text-8xl font-black text-white leading-[1.02] mb-6 tracking-tight"
            style="text-shadow: 0 2px 8px rgba(0,0,0,0.5);"
          >
            {Home.hero_title_html(
              if @settings["heading"] not in [nil, ""],
                do: @settings["heading"],
                else: @hero_title
            )}
          </h1>

          <%!-- Description --%>
          <p
            class="text-base sm:text-lg text-white max-w-xl leading-relaxed mb-8"
            style="text-shadow: 0 1px 4px rgba(0,0,0,0.6);"
          >
            {if @settings["subheading"] not in [nil, ""],
              do: @settings["subheading"],
              else: @hero_description}
          </p>

          <%!-- CTA Buttons --%>
          <div class="flex flex-col sm:flex-row gap-4">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center justify-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"
              style="background: var(--theme-accent, #166534);"
            >
              {if @settings["cta_label"] not in [nil, ""],
                do: @settings["cta_label"],
                else: @cta_text}
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
            <a
              href={store_path(@store.slug, "/about")}
              class="inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white border-2 border-white/40 hover:bg-white/10 transition-all duration-300 min-h-[48px]"
            >
              {@cta_secondary_text}
            </a>
          </div>
        </div>

        <%!-- Carousel Progress Indicators --%>
        <div :if={@use_carousel} class="flex gap-3 mt-10">
          <span
            :for={idx <- 0..(@image_count - 1)}
            class="relative h-1 rounded-full overflow-hidden"
            style={"width: #{max(32, 80 / @image_count)}px; background: rgba(255,255,255,0.25);"}
          >
            <span
              class="absolute inset-0 rounded-full"
              style={"background: white; animation: atelier-progress #{@total_duration / @image_count}s ease-in-out infinite #{idx * (@total_duration / @image_count)}s;"}
            >
            </span>
          </span>
        </div>
      </div>
    </section>
    """
  end

  # Returns true only for local upload paths (not stock photo URLs)
  defp prepare_hero_assigns(assigns) do
    theme = assigns[:theme] || %{}
    valid_images = collect_valid_hero_images(theme)
    image_count = length(valid_images)
    hero_carousel = get_in(theme, [:hero, :carousel]) || false
    store_name = Map.get(assigns.store, :name, "Our Store")

    assigns
    |> assign(:valid_images, valid_images)
    |> assign(:has_images, image_count > 0)
    |> assign(:use_carousel, image_count > 1 && hero_carousel)
    |> assign(:image_count, image_count)
    |> assign(:total_duration, max(image_count, 1) * 7)
    |> assign_hero_text(theme, store_name)
  end

  defp collect_valid_hero_images(theme) do
    images = get_in(theme, [:hero, :images]) || []
    single = get_in(theme, [:hero, :image_url])

    cond do
      is_list(images) && images != [] -> Enum.filter(images, &valid_hero_image?/1)
      valid_hero_image?(single) -> [single]
      true -> []
    end
  end

  defp assign_hero_text(assigns, theme, store_name) do
    assigns
    |> assign(:hero_subtitle, get_in(theme, [:hero, :subtitle]) || "Welcome to #{store_name}")
    |> assign(
      :hero_title,
      get_in(theme, [:hero, :title]) || "Crafting Trust,\nCurating Excellence."
    )
    |> assign(
      :hero_description,
      get_in(theme, [:hero, :description]) ||
        "Experience the soul of West African craftsmanship. Every piece tells a story of heritage, precision, and modern elegance."
    )
    |> assign(:cta_text, get_in(theme, [:hero, :cta_text]) || "Shop Now")
    |> assign(:cta_secondary_text, get_in(theme, [:hero, :cta_secondary_text]) || "Our Story")
  end

  defp valid_hero_image?(nil), do: false
  defp valid_hero_image?(""), do: false

  defp valid_hero_image?(url) when is_binary(url) do
    String.starts_with?(url, "/uploads/") || String.starts_with?(url, "/images/")
  end

  defp valid_hero_image?(_), do: false
end
