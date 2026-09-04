defmodule Emakola.Themes.Spotlight.Sections.ClosingCta do
  @moduledoc """
  Spotlight home closing statement — extracted verbatim from
  spotlight/home.ex.

  The button funnels to the hero product's page, so it only renders when the
  store has a product. Still gated by the legacy `@theme.sections.closing_cta`
  toggle underneath the section editor's own `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Spotlight.Shared

  @impl true
  def key, do: "spotlight/closing_cta"
  @impl true
  def label, do: "Closing CTA"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :text, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    closing = get_in(assigns.theme, [:closing_cta]) || %{}

    assigns =
      assigns
      |> assign(:hero_product, Layout.of(assigns).featured)
      |> assign(
        :heading,
        present(assigns.settings["heading"]) ||
          Map.get(closing, :title, "One product, done properly.")
      )
      |> assign(
        :subheading,
        present(assigns.settings["subheading"]) || Map.get(closing, :subtitle)
      )
      |> assign(
        :cta_label,
        present(assigns.settings["cta_label"]) || Map.get(closing, :button_text, "Get yours")
      )

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :closing_cta)}
      class="bg-[var(--theme-accent-soft)]"
    >
      <div class="max-w-[900px] mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <p class="spot-display text-3xl sm:text-4xl text-[#16130F] leading-tight">
          {@heading}
        </p>
        <p class="text-[#6B675F] mt-4">{@subheading}</p>
        <a
          :if={@hero_product}
          href={store_path(@store.slug, "/products/#{@hero_product.slug}")}
          class="inline-block mt-7 rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider"
        >
          {@cta_label}
        </a>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
