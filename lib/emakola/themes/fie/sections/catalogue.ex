defmodule Emakola.Themes.Fie.Sections.Catalogue do
  @moduledoc """
  Fie home catalogue — the numbered grid of plates.

  Each plate is numbered by its real position in the browse order and is
  typographically composed (index, price, initial on the blush ground)
  before any photo arrives — see `Emakola.Themes.Fie.Components`.

  A store with zero pieces renders an intentional being-prepared plate
  instead of nothing: a brand-new catalogue must never look broken to its
  first visitor (or to the merchant previewing it).
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fie.Components

  @impl true
  def key, do: "fie/catalogue"
  @impl true
  def label, do: "Catalogue"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "The Catalogue"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@products != []}
      class="bg-[#FDFCFB]"
      aria-labelledby="fie-catalogue-heading"
    >
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <div class="mb-6 flex items-baseline justify-between gap-4">
          <h2
            id="fie-catalogue-heading"
            class="text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-stone-500"
          >
            {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "The Catalogue"}
          </h2>
          <%!-- No piece count here: the home preview is capped upstream, so
          a count could lie for larger stores — link to the truth instead. --%>
          <a
            href={store_path(@store.slug, "/products")}
            class="text-xs font-medium text-stone-600 underline decoration-[#D8BCB0] underline-offset-2 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
          >
            Full catalogue
          </a>
        </div>
        <ol class="grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-3 md:gap-x-5 lg:grid-cols-4 lg:gap-x-6">
          <li :for={{product, index} <- Enum.with_index(@products, 1)}>
            <Components.catalogue_plate product={product} store={@store} index={index} />
          </li>
        </ol>
      </div>
    </section>
    <section
      :if={@products == []}
      class="bg-[#FDFCFB]"
      aria-labelledby="fie-catalogue-empty-heading"
    >
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <div class="border border-[#EBDAD3] bg-[#F7ECE7] px-6 py-16 text-center sm:py-20">
          <span
            class="mb-4 block select-none text-6xl font-medium text-[#D8BCB0] [font-family:'Space_Grotesk','Inter',sans-serif]"
            aria-hidden="true"
          >
            {String.first(@store.name)}
          </span>
          <h2
            id="fie-catalogue-empty-heading"
            class="mb-2 text-lg font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif]"
          >
            The catalogue is being prepared
          </h2>
          <p class="mx-auto max-w-sm text-sm leading-relaxed text-stone-600">
            {@store.name} hasn't listed any pieces yet — the first pages are on their way.
          </p>
        </div>
      </div>
    </section>
    """
  end
end
