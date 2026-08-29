defmodule Emakola.Themes.Adwuma.Sections.Hero do
  @moduledoc """
  Adwuma hero — a pastel mesh on near-white, framed by dashed blueprint rules.

  Takes **no image setting**. Every other theme's hero opens with an empty slab
  until the merchant uploads something; this one is finished the moment the shop
  exists. It also removes an upload, a bandwidth cost and a URL-injection
  surface from the most-viewed element on the site.

  The pill badges carry only platform-true facts. There is deliberately no
  "24/7 support" pill — no merchant promised that, and `reply within` is in the
  banned-promise regex for good reason.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "adwuma/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :text, label: "Subheading", default: ""},
      %{key: "cta_text", type: :string, label: "Button label", default: "Browse the shop"}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :heading, heading(assigns))

    ~H"""
    <section class="relative overflow-hidden bg-[color:var(--adw-bg)] [font-family:var(--adw-body)]">
      <div class="absolute inset-0 -z-10" style="background-image: var(--adw-mesh)"></div>

      <div class="mx-auto max-w-3xl px-4 py-24 text-center sm:px-6 sm:py-32">
        <div class="mx-auto max-w-2xl border border-dashed border-[color:var(--adw-rule)] px-6 py-12 sm:px-10">
          <h1
            id="adwuma-hero-heading"
            class="text-3xl font-semibold leading-tight tracking-tight text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-5xl"
          >
            {@heading}
          </h1>

          <p
            :if={@settings["subheading"] not in [nil, ""]}
            class="mx-auto mt-4 max-w-xl text-base text-[color:var(--adw-muted)]"
          >
            {@settings["subheading"]}
          </p>

          <a
            href={store_path(@store.slug, "/products")}
            class="mt-8 inline-flex items-center rounded-full bg-[color:var(--adw-ink)] px-7 py-3 text-sm font-semibold text-white hover:bg-[color:var(--adw-lavender)]"
          >
            {@settings["cta_text"] || "Browse the shop"}
          </a>
        </div>

        <ul class="mt-10 flex flex-wrap items-center justify-center gap-2.5">
          <li
            :for={badge <- badges()}
            class="rounded-full border border-[color:var(--adw-rule)] bg-white/70 px-4 py-1.5 text-xs font-medium text-[color:var(--adw-muted)]"
          >
            {badge}
          </li>
        </ul>
      </div>
    </section>
    """
  end

  # Merchant heading → theme hero title → the shop's own name. Never an empty
  # slab, and never invented copy.
  defp heading(assigns) do
    settings_heading = assigns.settings["heading"]
    theme_title = get_in(Map.get(assigns, :theme) || %{}, [:hero, :title])

    cond do
      settings_heading not in [nil, ""] -> settings_heading
      theme_title not in [nil, ""] -> theme_title
      true -> assigns.store.name
    end
  end

  defp badges, do: ["Mobile money", "Secure checkout", "Your own library"]
end
