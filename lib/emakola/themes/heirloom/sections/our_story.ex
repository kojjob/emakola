defmodule Emakola.Themes.Heirloom.Sections.OurStory do
  @moduledoc """
  A rail of chapter titles beside the open chapter's text and image.

  Driven by `@theme.our_story.tabs`, which defaults to `[]`. Populated, it
  would put the same craft-and-sustainability story on every Heirloom store
  — the reference's own copy, asserted on behalf of merchants who never
  wrote it. Empty, the section renders nothing.

  Each tab is `%{"title" => ..., "body" => ..., "image_url" => ...}`. All
  three are optional; a tab with no body still gets its title in the rail.

  The rail is a list of headings rather than interactive tabs. Switching the
  open chapter would need an event, and `StoreLive` handles only
  `search_overlay`, `add_to_cart` and `close_search` — an invented event
  name crashes the page instead of doing nothing. Every chapter renders,
  stacked; the reference's single-open-tab state buys nothing a shopper
  needs.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def key, do: "heirloom/our_story"

  @impl true
  def label, do: "Our story"

  @impl true
  def settings_schema do
    [%{key: "eyebrow", type: :string, label: "Eyebrow", default: "Our story"}]
  end

  @impl true
  def render(assigns) do
    tabs =
      assigns.theme
      |> get_in([:our_story, :tabs])
      |> List.wrap()
      |> Enum.filter(&is_map/1)

    assigns =
      assigns
      |> assign(:tabs, tabs)
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]))

    ~H"""
    <section :if={@tabs != []} class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32">
      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <p
          :if={@eyebrow}
          class="text-[11px] uppercase tracking-[0.16em] text-[color:var(--hl-muted)]"
        >
          {@eyebrow}
        </p>

        <div class="mt-10 space-y-20">
          <article
            :for={tab <- @tabs}
            class="grid items-start gap-10 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-16"
          >
            <h3 class="text-3xl font-light tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-4xl">
              {field(tab, "title")}
            </h3>

            <div class="grid gap-8 sm:grid-cols-2 sm:items-start">
              <div
                :if={field(tab, "image_url") != ""}
                class="overflow-hidden rounded-[28px] bg-[color:var(--hl-tile)]"
              >
                <.optimized_image
                  src={field(tab, "image_url")}
                  alt=""
                  width={720}
                  height={540}
                  class="aspect-[4/3] w-full object-cover"
                />
              </div>
              <p
                :if={field(tab, "body") != ""}
                class="max-w-prose text-sm leading-relaxed text-[color:var(--hl-muted)]"
              >
                {field(tab, "body")}
              </p>
            </div>
          </article>
        </div>
      </div>
    </section>
    """
  end

  defp field(tab, key) when is_map(tab) do
    value =
      Map.get(tab, key) ||
        Map.get(tab, safe_atom(key)) ||
        ""

    if is_binary(value), do: String.trim(value), else: ""
  end

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
