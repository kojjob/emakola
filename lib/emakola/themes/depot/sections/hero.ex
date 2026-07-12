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

    ~H"""
    <section class="border-b border-zinc-200 bg-white" aria-labelledby="depot-hero-heading">
      <div class="mx-auto max-w-[1120px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <p class="mb-3 font-mono text-[0.6875rem] font-semibold uppercase tracking-[0.2em] text-zinc-500">
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
          class="mt-6 inline-flex items-center gap-2 bg-store-accent px-6 py-3.5 text-[0.9375rem] font-bold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
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
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
