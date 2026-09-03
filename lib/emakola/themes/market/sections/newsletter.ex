defmodule Emakola.Themes.Market.Sections.Newsletter do
  @moduledoc """
  Market home email capture. The form fires `subscribe_newsletter`, handled
  platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view
  handler needed. Copy is honest: updates from this store, nothing else
  promised. Shown only once the stall is full enough to have news: four or
  more products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "market/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Stay in the loop"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
      aria-labelledby="market-newsletter-heading"
    >
      <div class="mx-auto max-w-[1280px] rounded-[20px] border border-stone-200 bg-white p-6 text-center sm:p-8">
        <h2
          id="market-newsletter-heading"
          class="mb-2 text-lg font-bold tracking-tight text-stone-900"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Stay in the loop"}
        </h2>
        <p class="mx-auto mb-5 max-w-[480px] text-sm leading-relaxed text-stone-600">
          New products and updates from {@store.name}, straight to your inbox.
        </p>
        <form
          id="market-newsletter-form"
          class="mx-auto flex max-w-lg flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="market-newsletter-email" class="sr-only">Email address</label>
          <input
            id="market-newsletter-email"
            type="email"
            name="email"
            placeholder="Enter your email"
            required
            class="min-h-[48px] flex-1 rounded-full border border-stone-200 bg-white px-5 py-3.5 text-sm text-stone-900 placeholder-stone-400 focus:outline-none focus:ring-2 focus:ring-stone-900"
          />
          <button
            type="submit"
            class="min-h-[48px] cursor-pointer whitespace-nowrap rounded-full bg-store-accent px-6 py-3.5 text-sm font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
          >
            Subscribe
          </button>
        </form>
        <p class="mt-3 text-xs text-stone-400">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
