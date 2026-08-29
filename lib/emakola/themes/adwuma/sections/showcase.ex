defmodule Emakola.Themes.Adwuma.Sections.Showcase do
  @moduledoc """
  The reference's wide media panel.

  Renders nothing until the merchant supplies a heading, body or image. An
  empty editorial slab is worse than no slab, and a merchant who writes little
  should never be punished with a hole in their shop.

  `image_url` is `:image_url`-typed so `HomeSections.sanitize_settings/2`
  rejects `javascript:` and `data:` schemes at write time. It is rendered only
  into an `<img src>`, never into a CSS `url()`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "adwuma/showcase"
  @impl true
  def label, do: "Wide panel"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "body", type: :text, label: "Body", default: ""},
      %{key: "image_url", type: :image_url, label: "Image", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :blank, blank?(assigns.settings))

    ~H"""
    <section
      :if={!@blank}
      class="bg-[color:var(--adw-bg)] px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20"
    >
      <div class="mx-auto max-w-5xl overflow-hidden rounded-2xl border border-[color:var(--adw-rule)] bg-white">
        <img
          :if={@settings["image_url"] not in [nil, ""]}
          src={@settings["image_url"]}
          alt={@settings["heading"] || ""}
          loading="lazy"
          class="aspect-[21/9] w-full object-cover"
        />
        <div :if={has_text?(@settings)} class="px-8 py-10 text-center">
          <h2
            :if={@settings["heading"] not in [nil, ""]}
            class="text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)]"
          >
            {@settings["heading"]}
          </h2>
          <p
            :if={@settings["body"] not in [nil, ""]}
            class="mx-auto mt-3 max-w-2xl text-base text-[color:var(--adw-muted)]"
          >
            {@settings["body"]}
          </p>
        </div>
      </div>
    </section>
    """
  end

  defp blank?(settings) do
    Enum.all?(["heading", "body", "image_url"], &(settings[&1] in [nil, ""]))
  end

  defp has_text?(settings) do
    settings["heading"] not in [nil, ""] or settings["body"] not in [nil, ""]
  end
end
