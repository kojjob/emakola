defmodule Emakola.Themes.Heirloom.Sections.BrandStory do
  @moduledoc """
  The large paragraph that reveals as it scrolls.

  The reference filled this with a three-generations family history. That is
  a provenance claim, and shipping it as a default would put the same
  invented heritage on every Heirloom store. The default is empty and the
  section renders nothing at all until a merchant writes their own.

  The reveal uses a CSS scroll-driven animation (`animation-timeline:
  view()`), not JavaScript. Where the browser does not support it the text
  simply renders at full opacity — the content is never hidden behind an
  effect that might not run, which matters on the low-end Android browsers
  most of this market uses.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "heirloom/brand_story"

  @impl true
  def label, do: "Brand story"

  @impl true
  def settings_schema do
    [%{key: "body", type: :text, label: "Story", default: ""}]
  end

  @impl true
  def render(assigns) do
    body =
      present(assigns.settings["body"]) ||
        present(get_in(assigns.theme, [:brand_story, :body]))

    assigns = assign(assigns, :body, body)

    ~H"""
    <section :if={@body} class="bg-[color:var(--hl-bg)] py-24 sm:py-32">
      <style>
        @supports (animation-timeline: view()) {
          @media (prefers-reduced-motion: no-preference) {
            .heirloom-reveal {
              animation: heirloom-reveal linear both;
              animation-timeline: view();
              animation-range: entry 20% cover 45%;
            }
            @keyframes heirloom-reveal {
              from { opacity: 0.25; }
              to { opacity: 1; }
            }
          }
        }
      </style>

      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <p class="heirloom-reveal max-w-[22ch] text-2xl font-light leading-[1.35] tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:max-w-[30ch] sm:text-4xl lg:text-5xl">
          {@body}
        </p>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
