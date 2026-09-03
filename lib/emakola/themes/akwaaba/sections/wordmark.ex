defmodule Emakola.Themes.Akwaaba.Sections.Wordmark do
  @moduledoc """
  Akwaaba wordmark band — a full-bleed amber field carrying the shop's name at
  display scale, with a product card floating over it.

  The name is set as a graphic, not as a heading: it is already announced by the
  hero's `<h1>` and the nav, so repeating it as an `<h2>` would just be noise to
  a screen reader. The floating card is the section's real content: the
  featured product from the shared Layout plan, which the grid leaves out so
  nothing on the page appears twice.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Akwaaba.Shared
  alias Emakola.Themes.Layout
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "akwaaba/wordmark"
  @impl true
  def label, do: "Wordmark band"

  @impl true
  def settings_schema do
    [%{key: "eyebrow", type: :string, label: "Eyebrow", default: "Featured"}]
  end

  @impl true
  def render(assigns) do
    featured = Layout.of(assigns).featured

    assigns =
      assigns
      |> assign(:featured, featured)
      |> assign(:image, featured && Shared.first_image(featured))
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]) || "Featured")

    ~H"""
    <section
      :if={@featured}
      class="relative overflow-hidden bg-[color:var(--akwaaba-amber)] [font-family:var(--akwaaba-body)]"
      aria-label={"Featured: #{@featured.title}"}
    >
      <p
        aria-hidden="true"
        class="pointer-events-none absolute inset-x-0 top-1/2 -translate-y-1/2 select-none truncate text-center text-[16vw] leading-none text-white/25 [font-family:var(--akwaaba-display)]"
      >
        {@store.name}
      </p>

      <div class="relative mx-auto max-w-[1320px] px-5 py-16 sm:px-10 sm:py-24">
        <div class="ml-auto flex max-w-md flex-col gap-4 rounded-3xl bg-white p-4 shadow-xl sm:flex-row sm:items-center sm:gap-5 sm:p-5">
          <div class="h-40 w-full flex-shrink-0 overflow-hidden rounded-2xl bg-[#F6F4F1] sm:h-32 sm:w-32">
            <div class="group relative h-full w-full">
              <Shared.photo_or_initial image={@image} title={@featured.title} sizes={[320, 320]} />
            </div>
          </div>

          <div class="min-w-0">
            <p class="text-[0.6875rem] font-bold uppercase tracking-[0.2em] text-[color:var(--akwaaba-sun)]">
              {@eyebrow}
            </p>
            <p class="mt-1 truncate text-xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
              {@featured.title}
            </p>
            <p class="mt-1 text-sm font-bold tabular-nums text-[color:var(--akwaaba-ink)]">
              {Currency.format_price_range(@featured.min_price, @featured.max_price, @store.currency)}
            </p>

            <a
              href={store_path(@store.slug, "/products/#{@featured.slug}")}
              class="mt-3 inline-flex items-center gap-2 rounded-full bg-[color:var(--akwaaba-ink)] px-5 py-2.5 text-xs font-bold text-white hover:bg-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-ink)] focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              View piece
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
