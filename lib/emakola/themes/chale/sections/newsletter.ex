defmodule Emakola.Themes.Chale.Sections.Newsletter do
  @moduledoc """
  Chale home email capture — drop alerts. The form fires
  `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view handler needed.
  Copy is honest: new stock from this store, nothing else promised. Shown
  only once the rack is full enough to have news: four or more products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "chale/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Don't miss the next drop"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="px-4 py-6 pb-10 sm:px-6 sm:py-8 lg:px-8"
      aria-labelledby="chale-newsletter-heading"
    >
      <div class="mx-auto max-w-[1280px] rounded-xl bg-[#101114] p-6 text-center text-white shadow-md sm:p-10">
        <h2
          id="chale-newsletter-heading"
          class="text-2xl font-bold uppercase tracking-tight [font-family:var(--chale-display)] sm:text-3xl"
        >
          {if @settings["heading"] not in [nil, ""],
            do: @settings["heading"],
            else: "Don't miss the next drop"}
        </h2>
        <p class="mx-auto mb-6 mt-2 max-w-md text-sm leading-relaxed text-zinc-300">
          New stock from {@store.name}, straight to your inbox.
        </p>
        <form
          id="chale-newsletter-form"
          class="mx-auto flex max-w-lg flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="chale-newsletter-email" class="sr-only">Email address</label>
          <input
            id="chale-newsletter-email"
            type="email"
            name="email"
            placeholder="your@email.com"
            required
            class="min-h-[48px] flex-1 border-2 border-white bg-white px-4 py-3 text-sm text-[#101114] placeholder-zinc-400 focus:outline-none focus:ring-2 focus:ring-store-accent"
          />
          <button
            type="submit"
            class="min-h-[48px] cursor-pointer whitespace-nowrap border-2 border-white bg-store-accent px-6 py-3 text-sm font-bold uppercase tracking-widest text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white motion-safe:transition-opacity motion-safe:active:translate-y-0.5"
          >
            Sign up
          </button>
        </form>
        <p class="mt-3 text-xs text-zinc-500">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
