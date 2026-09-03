defmodule Emakola.Themes.Fashion.Sections.Hero do
  @moduledoc """
  Fashion home hero — the magazine cover — extracted verbatim from
  `fashion/home.ex`.

  The theme's nav is *inside* the hero markup: a transparent on-dark header
  that the cover image is pulled up under by `-mt-20`, and whose `sticky`
  scope is the hero section itself. So it moves with the hero rather than
  being hoisted into chrome — hoisting would change both the DOM and the
  scroll behaviour of a theme with live merchants. With the hero switched
  off, Fashion has never rendered a nav; that coupling is today's, not the
  retrofit's.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/hero"

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
    theme = assigns.theme

    assigns =
      assigns
      # The section editor's preview renders theme markup without a cart.
      |> assign(:cart_count, assigns[:cart_count] || 0)
      |> assign(:hero_image_url, hero_image_url(theme))
      |> assign(:issue_eyebrow, issue_eyebrow(theme))
      |> assign(:issue_date, issue_date())
      |> assign(
        :hero_title,
        setting_or(assigns, "heading", theme.hero.title || "The new collection")
      )
      |> assign(
        :hero_subtitle,
        setting_or(assigns, "subheading", hero_subtitle(theme, assigns.store))
      )
      |> assign(
        :hero_cta_text,
        setting_or(assigns, "cta_label", theme.hero.cta_text || "Shop the Drop")
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :hero)} class="relative">
      <Shared.fashion_nav store={@store} cart_count={@cart_count} on_dark={true} />

      <div class="relative -mt-20 h-[70vh] min-h-[560px] max-h-[820px] overflow-hidden">
        <%= if @hero_image_url do %>
          <img
            src={@hero_image_url}
            alt="Editorial cover"
            class="absolute inset-0 w-full h-full object-cover"
          />
        <% else %>
          <div class="absolute inset-0 bg-gradient-to-br from-[#5B21B6] via-[#3B0F7E] to-[#1F0750]">
          </div>
        <% end %>
        <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-black/40"></div>

        <%!-- Issue marker top-right --%>
        <div class="absolute top-24 right-4 sm:right-8 lg:right-12 text-white/80 text-right">
          <p class="text-[11px] uppercase tracking-[0.3em] mb-1">
            {@issue_eyebrow}
          </p>
          <p class="fashion-heading italic text-base">
            {@issue_date}
          </p>
        </div>

        <%!-- Headline bottom-left --%>
        <div class="absolute inset-x-0 bottom-0 px-4 sm:px-8 lg:px-16 pb-12 sm:pb-16 lg:pb-20">
          <div class="max-w-3xl">
            <p class="text-[11px] sm:text-xs uppercase tracking-[0.3em] text-[#D97706] mb-4 sm:mb-6">
              The Spring Edit
            </p>
            <h1 class="fashion-display text-5xl sm:text-7xl lg:text-8xl text-white leading-[0.95] mb-6 sm:mb-8 max-w-2xl">
              {@hero_title}
            </h1>
            <p
              :if={@hero_subtitle}
              class="text-base sm:text-lg text-white/85 leading-relaxed mb-8 max-w-md italic fashion-heading"
            >
              {@hero_subtitle}
            </p>
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#B45309] text-white text-sm font-bold uppercase tracking-wider hover:bg-[#92400E] transition-colors min-h-[48px]"
            >
              {@hero_cta_text}
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Helpers ──

  # A merchant's section setting wins; where they have set nothing, the theme's
  # own copy renders exactly as it did before the retrofit.
  defp setting_or(assigns, key, fallback) do
    case assigns[:settings][key] do
      value when value not in [nil, ""] -> value
      _blank -> fallback
    end
  end

  # The theme's sample subtitle described goods this shop may not sell. Under
  # the store's name, only the merchant's own description can stand.
  defp hero_subtitle(theme, store) do
    present(get_in(theme, [:hero, :subtitle])) || present(Map.get(store, :description))
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  defp hero_image_url(theme) do
    case get_in(theme, [:hero, :images]) || [] do
      [first | _] when is_binary(first) ->
        first

      _ ->
        case get_in(theme, [:hero, :image_url]) do
          url when is_binary(url) and url != "" -> url
          _ -> nil
        end
    end
  end

  defp issue_eyebrow(theme),
    do: get_in(theme, [:editorial_intro, :eyebrow]) || "New collection"

  defp issue_date do
    Calendar.strftime(DateTime.utc_now(), "%B %Y")
  end
end
