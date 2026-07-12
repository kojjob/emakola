defmodule Emakola.Themes.Depot.Sections.Hero do
  @moduledoc """
  Depot home masthead — carries the page's `<h1>`.

  Deliberately image-free: the buyer is a shop owner restocking, and a
  lifestyle photo between them and the order sheet is friction. A mono
  kicker, a display headline in the merchant's heading family, the store
  description, and one CTA to the catalogue. The CTA always links to the
  server-generated products path — a merchant-controlled href here would
  be a stored-XSS sink, so no URL setting exists.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "depot/hero"
  @impl true
  def label, do: "Masthead"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: ""},
      %{key: "subheadline", type: :text, label: "Subheadline", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: "Browse the catalogue"}
    ]
  end

  @impl true
  def render(assigns) do
    custom_headline = present(assigns.settings["headline"])

    assigns =
      assigns
      |> assign(:custom_headline, custom_headline)
      |> assign(:headline, custom_headline || assigns.store.name)
      |> assign(
        :subheadline,
        present(assigns.settings["subheadline"]) || present(assigns.store.description)
      )
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Browse the catalogue")
      # Categories load in full on the home page, so their count is true. The
      # products do NOT — they arrive as a capped preview — so this block will
      # never state a catalogue size. A trade buyer reads these as facts.
      |> assign(:category_count, assigns |> Map.get(:categories, []) |> length())

    ~H"""
    <section class="border-b border-[#E7E5E1] bg-white" aria-labelledby="depot-hero-heading">
      <div class="mx-auto grid max-w-[1120px] gap-8 px-4 py-10 sm:px-6 sm:py-14 lg:grid-cols-[1fr_auto] lg:items-end lg:gap-16 lg:px-8">
        <div>
          <p class="mb-3 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-[#C2410C]">
            {if @custom_headline, do: @store.name, else: "Order desk"}
          </p>
          <h1
            id="depot-hero-heading"
            class="max-w-3xl text-3xl font-bold leading-[1.08] tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)] sm:text-4xl lg:text-5xl"
          >
            {@headline}
          </h1>
          <p :if={@subheadline} class="mt-3 max-w-2xl text-base leading-relaxed text-zinc-600">
            {@subheadline}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="mt-6 inline-flex items-center gap-2 bg-store-accent px-6 py-3.5 text-[0.9375rem] font-bold leading-none text-white hover:bg-[#C2410C] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#C2410C] focus-visible:ring-offset-2 motion-safe:transition-colors motion-safe:active:scale-[0.98]"
          >
            {@cta_label}
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
              />
            </svg>
          </a>
        </div>

        <%!-- The spec block: the docket stapled to the masthead. Every figure
        is one the store really has — no invented SLA, no invented volume. --%>
        <dl class="grid w-full grid-cols-2 border border-[#E7E5E1] bg-[#FAF9F7] sm:w-auto sm:grid-cols-2">
          <div :if={@category_count > 0} class="border-b border-r border-[#E7E5E1] px-5 py-4">
            <dt class="font-mono text-[0.625rem] font-semibold uppercase tracking-[0.18em] text-zinc-500">
              Categories
            </dt>
            <dd class="mt-1 font-mono text-2xl font-semibold tabular-nums text-zinc-900">
              {@category_count}
            </dd>
          </div>
          <div class="border-b border-[#E7E5E1] px-5 py-4">
            <dt class="font-mono text-[0.625rem] font-semibold uppercase tracking-[0.18em] text-zinc-500">
              Currency
            </dt>
            <dd class="mt-1 font-mono text-2xl font-semibold text-zinc-900">{@store.currency}</dd>
          </div>
          <div class="col-span-2 px-5 py-4">
            <dt class="font-mono text-[0.625rem] font-semibold uppercase tracking-[0.18em] text-zinc-500">
              Payment
            </dt>
            <dd class="mt-1 text-sm font-semibold text-zinc-900">Mobile money &amp; card</dd>
          </div>
        </dl>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
