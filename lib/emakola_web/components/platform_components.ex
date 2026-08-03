defmodule EmakolaWeb.PlatformComponents do
  @moduledoc """
  Shared building blocks for the platform-admin dashboards — the "Makola Admin
  design language": elevated stat tiles and a consistent page header. Imported
  into LiveViews via `EmakolaWeb` html helpers so every platform page can stay
  visually cohesive.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

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

  @severity_classes %{
    "blue" => "bg-blue-50 text-blue-700 ring-blue-600/20",
    "indigo" => "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
    "emerald" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
    "amber" => "bg-amber-50 text-amber-700 ring-amber-600/20",
    "violet" => "bg-violet-50 text-violet-700 ring-violet-600/20",
    "rose" => "bg-rose-50 text-rose-700 ring-rose-600/20",
    "green" => "bg-green-50 text-green-700 ring-green-600/20",
    "red" => "bg-red-50 text-red-700 ring-red-600/20",
    "slate" => "bg-slate-100 text-slate-600 ring-slate-500/20"
  }

  @doc """
  A ring-inset severity/status pill — extracted from the connection-status
  badges on `admin/supply_network_live.ex` (`status_classes/1`) into a shared
  platform primitive, so basis, readiness, payout-status and remediation
  pills all render from one family instead of four bespoke ones. `tone` picks
  the color family (same names as `stat_tile`'s `color`); `label` is shown
  verbatim — this component does not capitalize or transform it.
  """
  attr :label, :string, required: true
  attr :tone, :string, default: "slate"

  def severity_pill(assigns) do
    assigns =
      assign(
        assigns,
        :classes,
        Map.get(@severity_classes, assigns.tone, @severity_classes["slate"])
      )

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold ring-1 ring-inset",
      @classes
    ]}>
      {@label}
    </span>
    """
  end

  @doc """
  Platform-side "nothing here yet" empty state — icon, title, optional
  description. Mirrors `AdminComponents.empty_state/1`'s API but is named
  distinctly: `AdminComponents` and `PlatformComponents` are both imported,
  unqualified, into every LiveView's `html_helpers`, so a second same-named
  `empty_state/1` would make every existing `<.empty_state>` call site
  ambiguous at compile time.
  """
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :description, :string, default: nil

  def platform_empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center text-center py-16 px-6 bg-white border border-dashed border-gray-200 rounded-2xl">
      <div class="w-16 h-16 rounded-2xl bg-gray-50 flex items-center justify-center mb-4">
        <.icon name={@icon} class="w-8 h-8 text-gray-400" />
      </div>
      <h3 class="text-base font-semibold text-gray-900">{@title}</h3>
      <p :if={@description} class="text-sm text-gray-500 mt-1 max-w-md">{@description}</p>
    </div>
    """
  end
end
