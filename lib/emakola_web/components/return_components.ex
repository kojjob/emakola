defmodule EmakolaWeb.ReturnComponents do
  @moduledoc """
  Shared UI components for the return/refund flow.

  Provides status badges, timeline visualization, and reason labels
  used by both the admin return management page and the customer account page.
  """
  use Phoenix.Component

  @doc """
  Renders a color-coded status badge for a return.

  - requested: amber
  - approved: green
  - denied: red
  - refunded: blue
  """
  attr :status, :atom, required: true

  def return_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
      status_badge_classes(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  @doc """
  Renders a visual timeline showing the return progress.

  Shows dots for each stage with connecting lines. Completed stages
  are filled, current stage is highlighted, and future stages are grey.
  """
  attr :status, :atom, required: true

  def return_timeline(assigns) do
    assigns = assign(assigns, :steps, timeline_steps(assigns.status))

    ~H"""
    <div class="flex items-center gap-0">
      <div :for={{step, idx} <- Enum.with_index(@steps)} class="flex items-center">
        <div
          :if={idx > 0}
          class={[
            "w-8 h-0.5",
            if(step.completed, do: "bg-[#B45309]", else: "bg-stone-200")
          ]}
        />
        <div class="flex flex-col items-center gap-1">
          <div class={[
            "w-3 h-3 rounded-full border-2",
            cond do
              step.current -> "bg-[#B45309] border-[#B45309]"
              step.completed -> "bg-[#B45309] border-[#B45309]"
              true -> "bg-white border-stone-300"
            end
          ]} />
          <span class={[
            "text-[10px] font-medium whitespace-nowrap",
            if(step.current or step.completed, do: "text-[#1C1917]", else: "text-stone-400")
          ]}>
            {step.label}
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Returns a human-readable label for a return reason atom.
  """
  attr :reason, :atom, required: true

  def reason_label(assigns) do
    ~H"""
    <span>{reason_text(@reason)}</span>
    """
  end

  # -- Private helpers --

  defp status_badge_classes(:requested), do: "bg-amber-50 text-amber-700"
  defp status_badge_classes(:approved), do: "bg-green-50 text-green-700"
  defp status_badge_classes(:denied), do: "bg-red-50 text-red-700"
  defp status_badge_classes(:refunded), do: "bg-blue-50 text-blue-700"
  defp status_badge_classes(_), do: "bg-stone-50 text-stone-700"

  defp status_label(:requested), do: "Requested"
  defp status_label(:approved), do: "Approved"
  defp status_label(:denied), do: "Denied"
  defp status_label(:refunded), do: "Refunded"
  defp status_label(_), do: "Unknown"

  defp reason_text(:defective), do: "Defective item"
  defp reason_text(:wrong_item), do: "Wrong item received"
  defp reason_text(:not_as_described), do: "Not as described"
  defp reason_text(:changed_mind), do: "Changed mind"
  defp reason_text(:other), do: "Other"
  defp reason_text(_), do: "Unknown"

  defp timeline_steps(:requested) do
    [
      %{label: "Requested", completed: true, current: true},
      %{label: "Reviewed", completed: false, current: false},
      %{label: "Refunded", completed: false, current: false}
    ]
  end

  defp timeline_steps(:approved) do
    [
      %{label: "Requested", completed: true, current: false},
      %{label: "Approved", completed: true, current: true},
      %{label: "Refunded", completed: false, current: false}
    ]
  end

  defp timeline_steps(:denied) do
    [
      %{label: "Requested", completed: true, current: false},
      %{label: "Denied", completed: true, current: true}
    ]
  end

  defp timeline_steps(:refunded) do
    [
      %{label: "Requested", completed: true, current: false},
      %{label: "Approved", completed: true, current: false},
      %{label: "Refunded", completed: true, current: true}
    ]
  end

  defp timeline_steps(_), do: []
end
