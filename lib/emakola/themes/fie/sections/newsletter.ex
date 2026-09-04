defmodule Emakola.Themes.Fie.Sections.Newsletter do
  @moduledoc """
  Fie home email capture. The form fires `subscribe_newsletter`, handled
  platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view
  handler needed. Copy is honest: new catalogue pages from this store,
  nothing else promised. Shown only once the catalogue is full enough to
  have news: four or more pieces.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "fie/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "New pieces, first"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="border-t border-[#EBDAD3] bg-[#FDFCFB]"
      aria-labelledby="fie-newsletter-heading"
    >
      <div class="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <div class="mx-auto max-w-xl text-center">
          <h2
            id="fie-newsletter-heading"
            class="mb-2 text-2xl font-medium tracking-tight text-stone-900 [font-family:'Space_Grotesk','Inter',sans-serif]"
          >
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: "New pieces, first"}
          </h2>
          <p class="mb-6 text-sm leading-relaxed text-stone-600">
            New catalogue pages from {@store.name}, straight to your inbox.
          </p>
          <form
            id="fie-newsletter-form"
            class="flex flex-col gap-3 sm:flex-row"
            phx-submit="subscribe_newsletter"
          >
            <label for="fie-newsletter-email" class="sr-only">Email address</label>
            <input
              id="fie-newsletter-email"
              type="email"
              name="email"
              placeholder="Enter your email"
              required
              class="min-h-[48px] flex-1 border border-[#EBDAD3] bg-white px-4 py-3 text-sm text-stone-900 placeholder-stone-400 focus:outline-none focus:ring-2 focus:ring-stone-900"
            />
            <button
              type="submit"
              class="min-h-[48px] cursor-pointer whitespace-nowrap bg-store-accent px-7 py-3 text-sm font-semibold leading-none text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-opacity motion-safe:active:scale-[0.98]"
            >
              Subscribe
            </button>
          </form>
          <p class="mt-3 text-xs text-stone-400">No spam. Unsubscribe anytime.</p>
        </div>
      </div>
    </section>
    """
  end
end
