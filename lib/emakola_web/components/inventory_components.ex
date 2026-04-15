defmodule EmakolaWeb.InventoryComponents do
  @moduledoc """
  Shared UI components for the inventory management page.

  Provides stock status badges and stat cards used by the admin inventory dashboard.
  """
  use Phoenix.Component

  @doc """
  Renders a color-coded stock status badge.

  - Green "In Stock" when quantity >= 10
  - Amber "Low Stock" when quantity 1-9
  - Red "Out of Stock" with pulse dot when quantity is 0
  """
  attr :quantity, :integer, required: true

  def stock_status_badge(assigns) do
    {label, color_classes, show_pulse} = stock_status(assigns.quantity)
    assigns = assign(assigns, label: label, color_classes: color_classes, show_pulse: show_pulse)

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold",
      @color_classes
    ]}>
      <span
        :if={@show_pulse}
        class="relative flex h-2 w-2"
      >
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
      </span>
      {@label}
    </span>
    """
  end

  @doc """
  Renders an overview stat card with icon area, value, and label.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, required: true

  slot :icon, required: true

  def stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-5">
      <div class="flex items-center gap-3">
        <div class={[
          "flex items-center justify-center w-10 h-10 rounded-xl",
          icon_bg_class(@color)
        ]}>
          {render_slot(@icon)}
        </div>
        <div>
          <p class={["text-2xl font-bold", value_color_class(@color)]}>
            {@value}
          </p>
          <p class="text-xs font-medium text-slate-500 uppercase tracking-wider">
            {@label}
          </p>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp stock_status(qty) when qty >= 10, do: {"In Stock", "bg-emerald-50 text-emerald-700", false}
  defp stock_status(qty) when qty >= 1, do: {"Low Stock", "bg-amber-50 text-amber-700", false}
  defp stock_status(_qty), do: {"Out of Stock", "bg-red-50 text-red-700", true}

  defp icon_bg_class("emerald"), do: "bg-emerald-50"
  defp icon_bg_class("amber"), do: "bg-amber-50"
  defp icon_bg_class("red"), do: "bg-red-50"
  defp icon_bg_class("slate"), do: "bg-slate-100"
  defp icon_bg_class(_), do: "bg-slate-100"

  defp value_color_class("emerald"), do: "text-emerald-600"
  defp value_color_class("amber"), do: "text-amber-600"
  defp value_color_class("red"), do: "text-red-600"
  defp value_color_class("slate"), do: "text-slate-800"
  defp value_color_class(_), do: "text-slate-800"
end
