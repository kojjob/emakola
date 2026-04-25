defmodule Emakola.PageBuilder.Blocks.Spacer do
  @moduledoc """
  Vertical breathing room between blocks. Useful when two adjacent content
  blocks would otherwise crowd each other.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `height` | "sm" \\| "md" \\| "lg" \\| "xl" | "md" |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  @impl true
  def type, do: "spacer"

  @impl true
  def name, do: "Spacer"

  @impl true
  def icon, do: "height"

  @impl true
  def default_content, do: %{height: "md"}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :height_class, height_class(assigns.content[:height]))

    ~H"""
    <div class={@height_class} aria-hidden="true"></div>
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

  defp height_class("sm"), do: "h-6 sm:h-8"
  defp height_class("lg"), do: "h-16 sm:h-24"
  defp height_class("xl"), do: "h-24 sm:h-32"
  defp height_class(_), do: "h-10 sm:h-14"
end
