defmodule EmakolaWeb.InventoryComponents do
  @moduledoc """
  Shared UI components for the inventory management page.

  Provides stock status badges used by the admin inventory dashboard.
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

  # ── Helpers ──

  defp stock_status(qty) when qty >= 10, do: {"In Stock", "bg-emerald-50 text-emerald-700", false}
  defp stock_status(qty) when qty >= 1, do: {"Low Stock", "bg-amber-50 text-amber-700", false}
  defp stock_status(_qty), do: {"Out of Stock", "bg-red-50 text-red-700", true}
end
