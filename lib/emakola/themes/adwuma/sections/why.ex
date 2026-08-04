defmodule Emakola.Themes.Adwuma.Sections.Why do
  @moduledoc """
  Four numbered cards, in the reference's 01–04 band.

  The content is fixed and platform-true, exactly as `Akwaaba.Sections.Usp` is.
  Nothing here is a merchant promise, so nothing here can become a merchant's
  lie — and a merchant who reads little has no per-card copy to write or to get
  wrong. The numerals and icons carry the labelling.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "adwuma/why"
  @impl true
  def label, do: "Why buy here"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Why buy here"}]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="bg-[color:var(--adw-bg)] px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20">
      <div class="mx-auto max-w-5xl">
        <h2 class="text-center text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-3xl">
          {@settings["heading"] || "Why buy here"}
        </h2>

        <ul class="mt-10 grid gap-px overflow-hidden rounded-2xl border border-[color:var(--adw-rule)] bg-[color:var(--adw-rule)] sm:grid-cols-2 lg:grid-cols-4">
          <li :for={{card, index} <- Enum.with_index(cards(@store))} class="bg-white p-6">
            <p class="text-xs font-semibold tabular-nums text-[color:var(--adw-muted)]">
              {String.pad_leading(to_string(index + 1), 2, "0")}
            </p>
            <p class="mt-3 text-base font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
              {card.title}
            </p>
            <p class="mt-1 text-sm text-[color:var(--adw-muted)]">{card.body}</p>
            <a
              :if={card.href}
              href={card.href}
              class="mt-3 inline-block text-sm font-medium text-[color:var(--adw-lavender)] underline"
            >
              {card.link_label}
            </a>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp cards(store) do
    [
      %{
        title: "Pay with MoMo",
        body: "MTN, Telecel, AirtelTigo.",
        href: nil,
        link_label: nil
      },
      %{
        title: "In your account",
        body: "Downloads arrive after payment.",
        href: nil,
        link_label: nil
      },
      %{
        title: "Your library",
        body: "Everything you bought, in one place.",
        href: store_path(store.slug, "/account/downloads"),
        link_label: "Open library"
      },
      %{
        title: "Questions?",
        body: "Message the shop directly.",
        href: store_path(store.slug, "/contact"),
        link_label: "Contact"
      }
    ]
  end
end
