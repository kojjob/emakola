defmodule Emakola.Themes.Akwaaba.Sections.Newsletter do
  @moduledoc """
  Akwaaba promo banner — amber field, one line of copy, email capture.

  `subscribe_newsletter` is handled by `EmakolaWeb.Hooks.NewsletterSubscription`,
  attached to every storefront live_session. A `phx-submit` naming any other
  event would crash the page — five themes once shipped exactly that.

  Shown only once the shop is a full stall with news to send: four or more
  products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "akwaaba/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: "Be first to know"},
      %{
        key: "subheading",
        type: :text,
        label: "Subheading",
        default: "New pieces and offers, straight to your inbox."
      },
      %{key: "button_label", type: :string, label: "Button label", default: "Subscribe"}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <section
      :if={@layout.show_newsletter?}
      class="bg-white px-5 pb-16 [font-family:var(--akwaaba-body)] sm:px-10"
      aria-labelledby="akwaaba-newsletter-heading"
    >
      <div class="mx-auto max-w-[1320px] overflow-hidden rounded-[2rem] bg-[color:var(--akwaaba-amber)] px-6 py-12 text-center sm:px-10 sm:py-16">
        <h2
          id="akwaaba-newsletter-heading"
          class="text-3xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-4xl"
        >
          {@settings["heading"] || "Be first to know"}
        </h2>
        <p class="mx-auto mt-2 max-w-md text-sm text-[color:var(--akwaaba-ink)]/70">
          {@settings["subheading"] || "New pieces and offers, straight to your inbox."}
        </p>

        <form
          id="akwaaba-newsletter-form"
          phx-submit="subscribe_newsletter"
          class="mx-auto mt-7 flex w-full max-w-md flex-col gap-3 sm:flex-row"
        >
          <label for="akwaaba-newsletter-email" class="sr-only">Email address</label>
          <input
            id="akwaaba-newsletter-email"
            type="email"
            name="email"
            required
            placeholder="you@example.com"
            class="min-h-[48px] w-full flex-1 rounded-full border-0 bg-white px-5 text-sm text-[color:var(--akwaaba-ink)] placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-[color:var(--akwaaba-ink)]"
          />
          <button
            type="submit"
            class="min-h-[48px] flex-shrink-0 rounded-full bg-[color:var(--akwaaba-ink)] px-7 text-sm font-bold text-white hover:bg-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-ink)] focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--akwaaba-amber)] motion-safe:transition-colors"
          >
            {@settings["button_label"] || "Subscribe"}
          </button>
        </form>

        <p class="mt-3 text-xs text-[color:var(--akwaaba-ink)]/50">No spam. Unsubscribe anytime.</p>
      </div>
    </section>
    """
  end
end
