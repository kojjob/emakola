defmodule Emakola.Themes.Heirloom.Sections.Faq do
  @moduledoc """
  Two columns: a standing intro on the left, the store's questions on the
  right.

  The questions are the store's own, loaded by `StoreLive` into
  `:page_content` and read through `ContentLoader` — the same source the
  `/faq` page uses, so the home page and that page can never disagree. A
  store that has written no FAQ gets no section, rather than a set of
  plausible questions it never answered.

  The accordion is a native `<details>`/`<summary>`. No JavaScript, and no
  CSS-checkbox toggle — `:checked` state lives in browser memory rather than
  the DOM, so LiveView's diffing drops it.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias EmakolaWeb.Storefront.ContentLoader

  @impl true
  def key, do: "heirloom/faq"

  @impl true
  def label, do: "FAQ"

  @impl true
  def settings_schema do
    [
      %{key: "eyebrow", type: :string, label: "Eyebrow", default: "FAQ"},
      %{key: "heading", type: :text, label: "Intro", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    items =
      (Map.get(assigns, :page_content) || %{})
      |> ContentLoader.list(:faq_items)

    assigns =
      assigns
      |> assign(:items, items)
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]))
      |> assign(:heading, present(assigns.settings["heading"]))

    ~H"""
    <section :if={@items != []} class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32">
      <div class="mx-auto grid max-w-[1360px] gap-12 px-5 sm:px-8 lg:grid-cols-2 lg:gap-20">
        <div>
          <p
            :if={@eyebrow}
            class="text-[11px] uppercase tracking-[0.16em] text-[color:var(--hl-muted)]"
          >
            {@eyebrow}
          </p>
          <p
            :if={@heading}
            class="mt-6 max-w-[20ch] text-3xl font-light leading-[1.15] tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-4xl"
          >
            {@heading}
          </p>
        </div>

        <div>
          <details
            :for={item <- @items}
            name="faq"
            class="group border-b border-[color:var(--hl-border)] py-6"
          >
            <summary class="flex cursor-pointer list-none items-center justify-between gap-6">
              <span class="text-lg font-light text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
                {field(item, "question")}
              </span>
              <span
                aria-hidden="true"
                class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-[color:var(--hl-border)] text-[color:var(--hl-ink)] motion-safe:transition-transform group-open:rotate-180"
              >
                &darr;
              </span>
            </summary>
            <p class="mt-4 max-w-prose text-sm leading-relaxed text-[color:var(--hl-muted)]">
              {field(item, "answer")}
            </p>
          </details>
        </div>
      </div>
    </section>
    """
  end

  # Stored page content can be keyed by string or atom depending on the write
  # path, so read both rather than trusting one.
  defp field(item, key) when is_map(item) do
    Map.get(item, key) || Map.get(item, String.to_existing_atom(key)) || ""
  rescue
    ArgumentError -> Map.get(item, key) || ""
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
