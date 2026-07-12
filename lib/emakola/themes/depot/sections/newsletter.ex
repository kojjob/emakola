defmodule Emakola.Themes.Depot.Sections.Newsletter do
  @moduledoc """
  Depot home stock alerts. For a trade buyer an email capture is a
  restock signal, not a marketing splash. The form fires
  `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view handler needed.
  Copy is honest: updates from this store, nothing else promised.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "depot/newsletter"
  @impl true
  def label, do: "Stock alerts"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Stock alerts"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      class="bg-zinc-50 px-4 py-6 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="depot-newsletter-heading"
    >
      <div class="mx-auto max-w-[1120px] border-2 border-zinc-900 bg-white p-6 sm:p-8">
        <div class="mx-auto max-w-xl text-center">
          <h2
            id="depot-newsletter-heading"
            class="mb-2 text-lg font-bold tracking-tight text-zinc-900 [font-family:var(--dt-heading-font,inherit)]"
          >
            {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Stock alerts"}
          </h2>
          <p class="mb-5 text-sm leading-relaxed text-zinc-600">
            Restock and price updates from {@store.name}, straight to your inbox.
          </p>
          <form
            id="depot-newsletter-form"
            class="flex flex-col gap-3 sm:flex-row"
            phx-submit="subscribe_newsletter"
          >
            <label for="depot-newsletter-email" class="sr-only">Email address</label>
            <input
              id="depot-newsletter-email"
              type="email"
              name="email"
              placeholder="you@yourshop.com"
              required
              class="min-h-[48px] flex-1 border border-zinc-300 bg-white px-4 py-3 text-sm text-zinc-900 placeholder-zinc-400 focus:outline-none focus:ring-2 focus:ring-zinc-900"
            />
            <button
              type="submit"
              class="min-h-[48px] cursor-pointer whitespace-nowrap bg-store-accent px-6 py-3 text-sm font-bold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
            >
              Subscribe
            </button>
          </form>
          <p class="mt-3 text-xs text-zinc-400">No spam. Unsubscribe anytime.</p>
        </div>
      </div>
    </section>
    """
  end
end
