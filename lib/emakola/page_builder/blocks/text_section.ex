defmodule Emakola.PageBuilder.Blocks.TextSection do
  @moduledoc """
  Long-form text block. Renders a heading and a body of plain text. Markdown
  rendering arrives in Phase 4 with a safe HTML sanitiser; for Phase 1 the
  body is rendered as plain text with line breaks preserved.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `title` | string \\| nil | nil |
  | `body` | string | "" |
  | `text_align` | "left" \\| "center" | "left" |
  | `bg` | "default" \\| "light" \\| "dark" | "default" |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  @impl true
  def type, do: "text_section"

  @impl true
  def name, do: "Text Section"

  @impl true
  def icon, do: "subject"

  @impl true
  def default_content do
    %{
      title: nil,
      body: "",
      text_align: "left",
      bg: "default"
    }
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:bg_class, bg_class(assigns.content[:bg]))
      |> assign(:text_class, text_class(assigns.content[:bg]))
      |> assign(:align_class, align_class(assigns.content[:text_align]))

    ~H"""
    <section class={["py-12 sm:py-16", @bg_class]}>
      <div class={["max-w-3xl mx-auto px-4 sm:px-6 lg:px-8", @align_class]}>
        <h2
          :if={@content[:title]}
          class={["text-3xl sm:text-4xl font-bold mb-5", @text_class]}
          style="font-family: 'Manrope', sans-serif;"
        >
          {@content[:title]}
        </h2>
        <div
          :if={@content[:body]}
          class={["text-base leading-relaxed whitespace-pre-line", body_text_class(@content[:bg])]}
          style="font-family: 'Inter', sans-serif;"
        >
          {@content[:body]}
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming in Phase 2 of the page builder.
    </p>
    """
  end

  defp bg_class("light"), do: "bg-[#FEF3C7]/30"
  defp bg_class("dark"), do: "bg-[#1C1917]"
  defp bg_class(_), do: "bg-[#FFFBEB]"

  defp text_class("dark"), do: "text-white"
  defp text_class(_), do: "text-[#1C1917]"

  defp body_text_class("dark"), do: "text-white/85"
  defp body_text_class(_), do: "text-[#44403C]"

  defp align_class("center"), do: "text-center"
  defp align_class(_), do: "text-left"
end
