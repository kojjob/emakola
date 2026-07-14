defmodule Emakola.Themes.Fashion.Sections.BrandStory do
  @moduledoc """
  Fashion home brand-story split — the merchant's story, or no section.

  The headline was hardcoded "Sewn in Accra. Worn worldwide.", and a store that
  had written no description was given one: "We work with tailors and weavers
  across Ghana … Every piece is sewn in small batches; nothing mass-produced."

  A shop reselling imported denim published both. Where the goods are made, and
  by whom, is not something a stylesheet can know — and a story is worth nothing
  precisely when the shop did not write it.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/brand_story"

  @impl true
  def label, do: "Brand story"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{
        key: "body",
        type: :text,
        label: "Your story — who makes your pieces, and where",
        default: ""
      }
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:headline, setting(assigns, "headline"))
      |> assign(:body, setting(assigns, "body") || present(assigns.store.description))

    ~H"""
    <section
      :if={@body && Shared.section_enabled?(@theme, :brand_story)}
      class="bg-white py-16 sm:py-24"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class="aspect-[3/4] bg-gradient-to-br from-[#5B21B6]/10 to-[#D97706]/10 flex items-center justify-center">
            <span class="material-symbols-outlined text-[#5B21B6]/40" style="font-size: 140px;">
              checkroom
            </span>
          </div>
          <div>
            <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-3">
              Our story
            </p>
            <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-6">
              {@headline || @store.name}
            </h2>
            <p class="text-base text-[#57534E] leading-relaxed mb-3 italic fashion-heading">
              {@body}
            </p>
            <a
              href={store_path(@store.slug, "/about")}
              class="inline-flex items-center gap-2 mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-[#5B21B6] hover:gap-3 transition-all"
            >
              Read the journal
              <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp setting(assigns, key) do
    case get_in(assigns, [Access.key(:settings, %{}), key]) do
      value when is_binary(value) -> present(value)
      _ -> nil
    end
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_), do: nil
end
