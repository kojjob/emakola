defmodule EmakolaWeb.PlatformComponents do
  @moduledoc """
  Shared building blocks for the platform-admin dashboards — the "Makola Admin
  design language": elevated stat tiles and a consistent page header. Imported
  into LiveViews via `EmakolaWeb` html helpers so every platform page can stay
  visually cohesive.
  """
  use Phoenix.Component

  @chip_classes %{
    "blue" => "bg-blue-100 text-blue-600",
    "indigo" => "bg-indigo-100 text-indigo-600",
    "emerald" => "bg-emerald-100 text-emerald-600",
    "amber" => "bg-amber-100 text-amber-600",
    "violet" => "bg-violet-100 text-violet-600",
    "rose" => "bg-rose-100 text-rose-600",
    "green" => "bg-green-100 text-green-600",
    "red" => "bg-red-100 text-red-600",
    "slate" => "bg-slate-100 text-slate-600"
  }

  @doc """
  An elevated metric tile: label + icon chip header over a large value.
  `icon` is a Material Symbols name; omit it for a plain tile.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil
  attr :color, :string, default: "slate"

  def stat_tile(assigns) do
    assigns =
      assign(assigns, :chip, Map.get(@chip_classes, assigns.color, @chip_classes["slate"]))

    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-500">{@label}</span>
        <span
          :if={@icon}
          class={["flex h-9 w-9 items-center justify-center rounded-xl", @chip]}
        >
          <span class="material-symbols-outlined text-[20px]">{@icon}</span>
        </span>
      </div>
      <p class="mt-3 text-3xl font-bold text-gray-900 tabular-nums">{@value}</p>
    </div>
    """
  end

  @doc "Consistent page header: title + optional subtitle + an optional actions slot."
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="mb-6 flex items-start justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-gray-500 mt-1">{@subtitle}</p>
      </div>
      <div :if={@actions != []} class="shrink-0">{render_slot(@actions)}</div>
    </div>
    """
  end
end
