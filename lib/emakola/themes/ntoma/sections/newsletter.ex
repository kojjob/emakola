defmodule Emakola.Themes.Ntoma.Sections.Newsletter do
  @moduledoc """
  Ntoma home email capture. The form fires `subscribe_newsletter`, handled
  platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view
  handler needed. Copy is honest: updates from this store, nothing else
  promised.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "ntoma/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Join the list"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="px-4 py-10 sm:px-6 sm:py-14 lg:px-8" aria-labelledby="ntoma-newsletter-heading">
      <div class="mx-auto max-w-[1280px] border border-[#E6D5B8] bg-[#FFFBF2] px-6 py-10 text-center sm:px-10 sm:py-12">
        <h2
          id="ntoma-newsletter-heading"
          class="mb-2 text-xl font-semibold uppercase tracking-tight text-[#2B1708] [font-family:var(--dt-heading-font,'Fraunces',Georgia,serif)] sm:text-2xl"
        >
          {if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: "Join the list"}
        </h2>
        <p class="mx-auto mb-6 max-w-[480px] text-sm leading-relaxed text-[#7A6248]">
          New pieces and updates from {@store.name}, straight to your inbox.
        </p>
        <form
          id="ntoma-newsletter-form"
          class="mx-auto flex max-w-lg flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="ntoma-newsletter-email" class="sr-only">Email address</label>
          <input
            id="ntoma-newsletter-email"
            type="email"
            name="email"
            placeholder="Enter your email"
            required
            class="min-h-[48px] flex-1 border border-[#E6D5B8] bg-white px-4 py-3.5 text-sm text-[#2B1708] placeholder-[#A08863] focus:outline-none focus:ring-2 focus:ring-[#2B1708]"
          />
          <button
            type="submit"
            class="min-h-[48px] cursor-pointer whitespace-nowrap bg-store-accent px-8 py-3.5 text-sm font-bold uppercase tracking-[0.14em] leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2B1708] focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.99]"
          >
            Subscribe
          </button>
        </form>
        <p class="mt-3 text-xs text-[#A08863]">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
