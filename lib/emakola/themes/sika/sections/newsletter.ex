defmodule Emakola.Themes.Sika.Sections.Newsletter do
  @moduledoc """
  Sika home private viewings — email capture, quietly.

  The form fires `subscribe_newsletter`, handled platform-wide by
  `EmakolaWeb.Hooks.NewsletterSubscription` — no per-view handler needed.
  Copy is honest: first sight of new pieces, nothing else promised. Shown
  only once the collection is full enough to have news: four or more
  pieces.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Sika.Shared

  @impl true
  def key, do: "sika/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Private viewings"}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:heading, Shared.present(assigns.settings["heading"]) || "Private viewings")
      |> assign(:layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="px-4 py-12 sm:px-6 sm:py-16 lg:px-8"
      aria-labelledby="sika-newsletter-heading"
    >
      <div class="mx-auto max-w-xl text-center">
        <h2
          id="sika-newsletter-heading"
          class="text-2xl text-[#211D16] [font-family:var(--dt-heading-font,Marcellus,Georgia,serif)]"
        >
          {@heading}
        </h2>
        <Shared.caught_light class="mx-auto mt-4 w-16" />
        <p class="mt-4 text-sm leading-relaxed text-[#6E675C]">
          Be the first to see new pieces from {@store.name}.
        </p>
        <form
          id="sika-newsletter-form"
          class="mx-auto mt-7 flex max-w-md flex-col gap-3 sm:flex-row"
          phx-submit="subscribe_newsletter"
        >
          <label for="sika-newsletter-email" class="sr-only">Email address</label>
          <input
            id="sika-newsletter-email"
            type="email"
            name="email"
            required
            placeholder="Your email address"
            class="min-h-[48px] flex-1 border border-[#E8E3D9] bg-white px-4 py-3 text-sm text-[#211D16] placeholder-[#A29B8C] focus:border-[#211D16] focus:outline-none focus:ring-1 focus:ring-[#211D16]"
          />
          <button
            type="submit"
            class="min-h-[48px] cursor-pointer whitespace-nowrap bg-store-accent px-7 py-3 text-[0.75rem] font-semibold uppercase tracking-[0.2em] text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#211D16] focus-visible:ring-offset-2 motion-safe:transition-opacity"
          >
            Subscribe
          </button>
        </form>
        <p class="mt-3 text-xs text-[#A29B8C]">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
