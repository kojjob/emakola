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

          <%!-- Scrim: the hero now carries the shop's own product photography,
          which can be bright and busy where the type sits. A flat dim would
          kill the photograph, so the weight goes where the words are — a wash
          up from the base and across from the left — leaving the right side of
          the image clean. --%>
          <div class="absolute inset-0 bg-black/25"></div>
          <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/35 to-transparent">
          </div>
          <div class="absolute inset-0 bg-gradient-to-r from-black/70 via-black/20 to-transparent">
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
        <div class={[
          "grid items-end gap-10",
          @hero_product_image && "lg:grid-cols-5 lg:gap-16"
        ]}>
          <div class={["max-w-3xl", @hero_product_image && "lg:col-span-3"]}>
            <%!-- The badge only exists if the merchant wrote one. An empty pill
          is worse than no pill, and an invented one is worse than both. --%>
            <span
              :if={@hero_subtitle}
              class="inline-block px-4 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 text-white"
              style="background: var(--theme-accent, #166534); text-shadow: none;"
            >
              {@hero_subtitle}
            </span>

            <%!-- Heading — the store's own name unless it says otherwise --%>
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

            <% description =
              if @settings["subheading"] not in [nil, ""],
                do: @settings["subheading"],
                else: @hero_description %>
            <p
              :if={description}
              class="text-base sm:text-lg text-white max-w-xl leading-relaxed mb-8"
              style="text-shadow: 0 1px 4px rgba(0,0,0,0.6);"
            >
              {description}
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

          <%!-- The shop's own photography, standing in a portrait frame instead
          of stretched across the band behind the type. It is one real product,
          named and priced from its own record, and it goes to that product. --%>
          <a
            :if={@hero_product_image}
            href={store_path(@store.slug, "/products/#{@hero_product.slug}")}
            class="group block w-full lg:col-span-2 lg:justify-self-end"
          >
            <div class="overflow-hidden rounded-2xl ring-1 ring-white/20 shadow-2xl">
              <.optimized_image
                src={@hero_product_image}
                alt={@hero_product.title}
                priority={:high}
                width={640}
                height={800}
                class="aspect-[4/5] w-full object-cover transition-transform duration-700 motion-safe:group-hover:scale-105"
              />
            </div>
            <div class="mt-4 flex items-baseline justify-between gap-4">
              <p class="truncate text-sm font-semibold text-white">
                {@hero_product.title}
              </p>
              <p class="shrink-0 text-sm font-bold tabular-nums text-white/80">
                {EmakolaWeb.Helpers.Currency.format_price_range(
                  @hero_product.min_price,
                  @hero_product.max_price,
                  @store.currency
                )}
              </p>
            </div>
          </a>
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

  # The hero carries one of two very different kinds of picture, and they want
  # different frames.
  #
  # Hero art the merchant uploads is COMPOSED for a full-bleed band, so it fills
  # the viewport behind the type — that full-height wash is Atelier's signature.
  #
  # A product photograph is not that. It is a tall portrait of a single thing,
  # and stretching one across a 100vh landscape band crops away half its height:
  # a model's head goes out the top and the storefront opens on a pair of legs.
  # So when the shop has never set hero art, we do not fake it — we stand the
  # product photograph in a portrait frame beside the type, over Atelier's own
  # gradient ground, the way every other theme frames the same picture.
  defp prepare_hero_assigns(assigns) do
    theme = assigns[:theme] || %{}
    configured = configured_hero_images(theme)
    image_count = length(configured)
    hero_carousel = get_in(theme, [:hero, :carousel]) || false
    store_name = Map.get(assigns.store, :name, "Our Store")
    hero_product = if configured == [], do: hero_product(Map.get(assigns, :products, []))

    assigns
    |> assign(:valid_images, configured)
    |> assign(:has_images, image_count > 0)
    |> assign(:use_carousel, image_count > 1 && hero_carousel)
    |> assign(:image_count, image_count)
    |> assign(:total_duration, max(image_count, 1) * 7)
    |> assign(:hero_product, hero_product)
    |> assign(:hero_product_image, hero_product && Shared.first_image(hero_product))
    |> assign_hero_text(theme, store_name)
  end

  defp configured_hero_images(theme) do
    images = get_in(theme, [:hero, :images]) || []
    single = get_in(theme, [:hero, :image_url])

    cond do
      is_list(images) && images != [] -> Enum.filter(images, &valid_hero_image?/1)
      valid_hero_image?(single) -> [single]
      true -> []
    end
  end

  # Product images are our own upload records, already rendered by every card on
  # this page, so they do not pass through the merchant-typed-URL gate that the
  # theme's image_url setting does.
  defp hero_product(products) do
    Enum.find(products, &Shared.first_image/1)
  end

  # The hero used to fall back to copy the merchant never wrote: a headline
  # ("Crafting Trust, Curating Excellence."), a badge ("The 2024 Collection")
  # and a paragraph about the soul of West African craftsmanship. It was the
  # <h1> of every Atelier storefront that had not overridden it — a shop
  # selling rice announced itself as a curator of masterpieces.
  #
  # The store speaks for itself now: its own name is the headline, its own
  # description the standfirst. Where it has said nothing, we print nothing.
  defp assign_hero_text(assigns, theme, store_name) do
    store = Map.get(assigns, :store, %{})

    assigns
    |> assign(:hero_subtitle, present(get_in(theme, [:hero, :subtitle])))
    |> assign(:hero_title, present(get_in(theme, [:hero, :title])) || store_name)
    |> assign(
      :hero_description,
      present(get_in(theme, [:hero, :description])) || present(Map.get(store, :description))
    )
    |> assign(:cta_text, present(get_in(theme, [:hero, :cta_text])) || "Shop now")
    |> assign(
      :cta_secondary_text,
      present(get_in(theme, [:hero, :cta_secondary_text])) || "Our story"
    )
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  defp valid_hero_image?(nil), do: false
  defp valid_hero_image?(""), do: false

  defp valid_hero_image?(url) when is_binary(url) do
    Emakola.Storage.trusted_media_url?(url)
  end

  defp valid_hero_image?(_), do: false
end
