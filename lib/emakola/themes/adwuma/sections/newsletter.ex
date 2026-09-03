defmodule Emakola.Themes.Adwuma.Sections.Newsletter do
  @moduledoc """
  A form that actually captures.

  `subscribe_newsletter` is handled by `EmakolaWeb.Hooks.NewsletterSubscription`
  on every storefront live_session. A `phx-submit` naming any other event, or an
  input without `name="email"`, is a form that silently swallows what a shopper
  types — `no_dead_forms_test` asserts both literals.

  Shown only once the shop is a full stall with news to send: four or more
  products.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout

  @impl true
  def key, do: "adwuma/newsletter"
  @impl true
  def label, do: "Newsletter"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: "New drops, in your inbox"},
      %{
        key: "subheading",
        type: :text,
        label: "Subheading",
        default: "Hear first when something new lands."
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
      class="relative overflow-hidden bg-[color:var(--adw-bg)] px-4 py-20 [font-family:var(--adw-body)] sm:px-6"
    >
      <div class="absolute inset-0 -z-10 opacity-60" style="background-image: var(--adw-mesh)"></div>

      <div class="mx-auto max-w-xl text-center">
        <h2 class="text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-3xl">
          {@settings["heading"] || "New drops, in your inbox"}
        </h2>
        <p class="mt-3 text-base text-[color:var(--adw-muted)]">
          {@settings["subheading"]}
        </p>

        <form phx-submit="subscribe_newsletter" class="mt-6 flex flex-col gap-3 sm:flex-row">
          <label for="adwuma-newsletter-email" class="sr-only">Email address</label>
          <input
            id="adwuma-newsletter-email"
            type="email"
            name="email"
            required
            placeholder="you@example.com"
            class="flex-1 rounded-full border border-[color:var(--adw-rule)] bg-white px-5 py-3 text-sm text-[color:var(--adw-ink)] focus:border-[color:var(--adw-lavender)] focus:outline-none"
          />
          <button
            type="submit"
            class="rounded-full bg-[color:var(--adw-ink)] px-7 py-3 text-sm font-semibold text-white hover:bg-[color:var(--adw-lavender)]"
          >
            {@settings["button_label"] || "Subscribe"}
          </button>
        </form>
      </div>
    </section>
    """
  end
end
