defmodule Emakola.Themes.Dede.Sections.Newsletter do
  @moduledoc """
  Fresh pot alerts — email capture on a small board. The form fires
  `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view handler needed.
  Copy is honest: menu updates from this kitchen, nothing else promised.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "dede/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Fresh pot alerts"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      class="px-4 py-4 sm:px-6 sm:py-6 lg:px-8"
      aria-labelledby="dede-newsletter-heading"
    >
      <div class="mx-auto max-w-[880px] rounded-2xl bg-[#1B2E23] p-6 text-center ring-1 ring-inset ring-white/10 sm:p-8">
        <h2
          id="dede-newsletter-heading"
          class="text-xl uppercase tracking-wide text-[#F3EDDF] [font-family:var(--dt-heading-font,'Anton',sans-serif)]"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Fresh pot alerts"}
        </h2>
        <p class="mx-auto mt-2 max-w-[440px] text-sm leading-relaxed text-[#A8BAA5]">
          Menu updates from {@store.name}, straight to your inbox.
        </p>
        <form
          id="dede-newsletter-form"
          class="mx-auto mt-5 flex max-w-md flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="dede-newsletter-email" class="sr-only">Email address</label>
          <input
            id="dede-newsletter-email"
            type="email"
            name="email"
            placeholder="Your email"
            required
            class="min-h-12 flex-1 rounded-full border-2 border-[#F3EDDF]/25 bg-[#FAF5EA] px-5 py-3 text-sm text-[#26211A] placeholder-[#6B6355] focus:outline-none focus:ring-2 focus:ring-[#F3EDDF]"
          />
          <button
            type="submit"
            class="min-h-12 cursor-pointer whitespace-nowrap rounded-full bg-[#F3EDDF] px-6 py-3 text-sm font-bold leading-none text-[#1B2E23] hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F3EDDF] focus-visible:ring-offset-2 focus-visible:ring-offset-[#1B2E23] motion-safe:transition-colors motion-safe:active:scale-[0.98]"
          >
            Subscribe
          </button>
        </form>
        <p class="mt-3 text-xs text-[#A8BAA5]/80">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
