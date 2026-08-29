defmodule EmakolaWeb.PlatformComponents do
  @moduledoc """
  Shared building blocks for the platform-admin dashboards — the "Makola Admin
  design language": elevated stat tiles and a consistent page header. Imported
  into LiveViews via `EmakolaWeb` html helpers so every platform page can stay
  visually cohesive.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]
  import EmakolaWeb.AdminComponents, only: [stat_card: 1]

  @doc """
  An elevated metric tile: label + icon chip header over a large value.
  `icon` is a Material Symbols name; omit it for a plain tile. `id`, when
  given, is stamped on the value element so tests can target it with a
  stable selector (`has_element?/3`) instead of matching rendered markup.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil
  attr :color, :string, default: "slate"
  attr :id, :string, default: nil

  def stat_tile(assigns) do
    # Platform tiles are the merchant admin's tiles. This delegates to the
    # shared stat_card rather than keeping a second implementation of the
    # same idea — that is how the two admins drifted apart (rounded-2xl vs
    # rounded-card, gray-* vs slate-*, a 36px chip vs a 56px tile).
    #
    # The call sites keep their own vocabulary (a colour name and a Material
    # icon name); both are translated here, so none of the 36 of them change.
    assigns =
      assigns
      |> assign(:tone, tone_for_color(assigns.color))
      |> assign(:hero_icon, hero_icon_for(assigns.icon))

    ~H"""
    <.stat_card id={@id} label={@label} value={to_string(@value)} tone={@tone}>
      <:icon :if={@hero_icon}><.icon name={@hero_icon} class="size-7" /></:icon>
    </.stat_card>
    """
  end

  # Map the call site's colour word to the tone that still LOOKS like it.
  # `:primary` is violet now, so routing "emerald" there would repaint every
  # green platform tile violet and leave the platform admin with no green at all.
  defp tone_for_color(color) when color in ["emerald", "green"], do: :success
  defp tone_for_color(color) when color in ["violet", "indigo"], do: :accent
  defp tone_for_color(color) when color in ["blue", "sky"], do: :info
  defp tone_for_color(color) when color in ["cyan", "teal"], do: :cyan
  defp tone_for_color(color) when color in ["amber", "yellow", "orange"], do: :warning
  defp tone_for_color(color) when color in ["red", "rose"], do: :danger
  defp tone_for_color(_slate), do: :neutral

  # The platform pages name icons in Material Symbols; the rest of the admin
  # draws Heroicons. Translating here lets both admins share one icon family
  # without touching every call site.
  @hero_icons %{
    "account_balance_wallet" => "hero-wallet",
    "autorenew" => "hero-arrow-path",
    "bolt" => "hero-bolt",
    "cancel" => "hero-x-circle",
    "check_circle" => "hero-check-circle",
    "currency_exchange" => "hero-currency-dollar",
    "error" => "hero-exclamation-circle",
    "fingerprint" => "hero-finger-print",
    "flag" => "hero-flag",
    "group" => "hero-users",
    "hourglass_empty" => "hero-clock",
    "inventory_2" => "hero-cube",
    "monitoring" => "hero-chart-bar",
    "payments" => "hero-banknotes",
    "people" => "hero-user-group",
    "percent" => "hero-receipt-percent",
    "shopping_bag" => "hero-shopping-bag",
    "storefront" => "hero-building-storefront",
    "trending_up" => "hero-arrow-trending-up",
    "undo" => "hero-arrow-uturn-left",
    "verified" => "hero-check-badge",
    "verified_user" => "hero-shield-check",
    "warning" => "hero-exclamation-triangle",
    "workspace_premium" => "hero-trophy"
  }

  defp hero_icon_for(nil), do: nil
  # An unmapped name falls back to a neutral glyph rather than rendering
  # nothing — a missing icon should look plain, not broken.
  defp hero_icon_for(name), do: Map.get(@hero_icons, name, "hero-chart-bar")

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

  @avatar_tints [
    "bg-rose-100 text-rose-600",
    "bg-amber-100 text-amber-600",
    "bg-blue-100 text-blue-600",
    "bg-emerald-100 text-emerald-600",
    "bg-sky-100 text-sky-600",
    "bg-violet-100 text-violet-600",
    "bg-indigo-100 text-indigo-600",
    "bg-green-100 text-green-700"
  ]

  @doc """
  Deterministic tinted letter avatar for a store — the tint is hashed from
  the store id so a store keeps its color everywhere it appears.
  """
  attr :store, :map, required: true
  attr :class, :string, default: "w-14 h-14 rounded-[14px] text-[22px]"

  def store_avatar(assigns) do
    tint = Enum.at(@avatar_tints, :erlang.phash2(assigns.store.id, length(@avatar_tints)))
    assigns = assign(assigns, :tint, tint)

    ~H"""
    <div class={[
      "flex items-center justify-center font-bold shrink-0",
      @tint,
      @class
    ]}>
      {@store.name |> String.first() |> String.upcase()}
    </div>
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
