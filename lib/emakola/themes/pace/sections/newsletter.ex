defmodule Emakola.Themes.Pace.Sections.Newsletter do
  @moduledoc """
  Pace home email capture — a night slab closing the canvas. The form
  fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view handler needed.
  Copy is honest: updates from this store, nothing else promised. Shown
  only once the lineup is full enough to have news: four or more products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "pace/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Stay on pace"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="px-5 py-4 sm:px-8 sm:py-5 lg:px-10"
      aria-labelledby="pace-newsletter-heading"
    >
      <div class="mx-auto max-w-[1280px] rounded-[24px] bg-gradient-to-br from-slate-900 to-slate-950 p-6 text-center text-white sm:p-10">
        <h2
          id="pace-newsletter-heading"
          class="pace-display mb-2 text-xl font-bold uppercase italic tracking-tight sm:text-2xl"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Stay on pace"}
        </h2>
        <p class="mx-auto mb-6 max-w-[480px] text-sm leading-relaxed text-slate-300">
          New drops and updates from {@store.name}, straight to your inbox.
        </p>
        <form
          id="pace-newsletter-form"
          class="mx-auto flex max-w-lg flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="pace-newsletter-email" class="sr-only">Email address</label>
          <input
            id="pace-newsletter-email"
            type="email"
            name="email"
            placeholder="Enter your email"
            required
            class="min-h-[48px] flex-1 rounded-full border border-white/20 bg-white/10 px-5 py-3.5 text-sm text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-white"
          />
          <button
            type="submit"
            class="min-h-[48px] cursor-pointer whitespace-nowrap rounded-full bg-store-accent px-6 py-3.5 text-sm font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-slate-950 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
          >
            Subscribe
          </button>
        </form>
        <p class="mt-3 text-xs text-slate-500">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
