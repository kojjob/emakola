defmodule EmakolaWeb.Admin.DeliveryLive.MetricsComponents do
  @moduledoc """
  The numbers beside the Delivery Zones settings: four tiles, the
  per-zone order and fee cells, the row for orders no zone matched, and
  the two summary cards. Every figure comes from
  `Emakola.Shipping.DeliveryMetrics`; nothing here estimates delivery
  time, because orders carry no delivery timestamps.
  """
  use EmakolaWeb, :html

  alias EmakolaWeb.Helpers.Currency

  attr :metrics, :map, required: true
  attr :zones, :list, required: true

  def metric_tiles(assigns) do
    assigns = assign(assigns, :paused, Enum.reject(assigns.zones, & &1.active))

    ~H"""
    <div id="delivery-metrics" class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div data-metric="delivered">
        <.stat_card label="Delivered · 30 days" value={to_string(@metrics.delivered)} tone={:success}>
          <:icon><.icon name="hero-check-badge" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-blue-700">
              {@metrics.on_the_way} on the way · {@metrics.to_pack} still to pack
            </span>
          </:delta>
        </.stat_card>
      </div>
      <div data-metric="fees">
        <.stat_card
          label="Delivery fees · 30 days"
          value={Currency.format_price(@metrics.fees_collected)}
          tone={:info}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-slate-500">
              {@metrics.free_deliveries} free · {Currency.format_price(@metrics.fees_waived)} waived
            </span>
          </:delta>
        </.stat_card>
      </div>
      <div data-metric="zones">
        <.stat_card
          label="Zones"
          value={"#{@metrics.zones_on} of #{length(@zones)} on"}
          tone={:accent}
        >
          <:icon><.icon name="hero-map-pin" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-slate-500">{paused_line(@paused)}</span>
          </:delta>
        </.stat_card>
      </div>
      <div data-metric="unmatched">
        <.stat_card
          label="No zone matched"
          value={to_string(@metrics.unmatched.orders)}
          tone={:warning}
        >
          <:icon><.icon name="hero-question-mark-circle" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-amber-700">
              {unmatched_line(@metrics.unmatched)}
            </span>
          </:delta>
        </.stat_card>
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :count, :integer, required: true
  attr :total, :integer, required: true
  attr :tone, :string, default: "bg-emerald-600"
  attr :muted, :boolean, default: false

  def share_bar(assigns) do
    width = if assigns.total > 0, do: round(assigns.count / assigns.total * 100), else: 0
    assigns = assign(assigns, :width, width)

    ~H"""
    <div class="flex items-center gap-3">
      <span class="flex-1 h-2 rounded bg-slate-200 overflow-hidden">
        <span class={["block h-full rounded", @tone]} style={"width: #{@width}%"}></span>
      </span>
      <span
        id={@id}
        class={[
          "w-6 text-right text-sm font-bold tabular-nums",
          if(@muted, do: "text-slate-400", else: "text-slate-900")
        ]}
      >
        {@count}
      </span>
    </div>
    """
  end

  attr :unmatched, :map, required: true
  attr :total_orders, :integer, required: true

  def unmatched_row(assigns) do
    ~H"""
    <tr :if={@unmatched.orders > 0} id="unmatched-zone-row" class="bg-amber-50/60">
      <td class="px-6 py-4" colspan="4">
        <div class="flex items-center gap-3">
          <span class="flex h-9 w-9 items-center justify-center rounded-[10px] bg-amber-100 text-amber-700 shrink-0">
            <.icon name="hero-question-mark-circle" class="size-[18px]" />
          </span>
          <div>
            <p class="text-sm font-bold text-amber-900">No zone matched</p>
            <p class="text-xs text-amber-700 mt-0.5">
              {regions_line(@unmatched.regions)} · paid the default fee. Zones match by name only.
            </p>
          </div>
        </div>
      </td>
      <td class="px-6 py-4">
        <.share_bar count={@unmatched.orders} total={@total_orders} tone="bg-amber-500" />
      </td>
      <td class="px-6 py-4 text-sm font-semibold text-amber-900 tabular-nums">
        {Currency.format_price(@unmatched.fees)}
      </td>
      <td class="px-6 py-4 text-right" colspan="2">
        <button
          type="button"
          phx-click="show_form"
          phx-value-name={top_region(@unmatched.regions)}
          class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
        >
          <.icon name="hero-plus" class="size-4" /> Add zone for {top_region(@unmatched.regions)}
        </button>
      </td>
    </tr>
    """
  end

  attr :metrics, :map, required: true
  attr :zones, :list, required: true

  def orders_by_zone(assigns) do
    assigns = assign(assigns, :rows, zone_rows(assigns.zones, assigns.metrics))

    ~H"""
    <.admin_card>
      <div class="flex items-baseline gap-2 mb-4">
        <h3 class="text-base font-bold text-slate-900">Where your orders go</h3>
        <span class="text-xs text-slate-500">{@metrics.total_orders} orders · 30 days</span>
      </div>
      <div class="space-y-3">
        <div
          :for={row <- @rows}
          class="grid grid-cols-[150px_minmax(0,1fr)_40px] items-center gap-3"
        >
          <span class={[
            "text-[13px] font-semibold truncate",
            row.tone == :warning && "text-amber-800",
            row.muted && "text-slate-400",
            !row.muted && row.tone != :warning && "text-slate-700"
          ]}>
            {row.name}
          </span>
          <span class="h-3.5 rounded bg-slate-200 overflow-hidden">
            <span
              class={[
                "block h-full rounded",
                if(row.tone == :warning, do: "bg-amber-500", else: "bg-emerald-600"),
                row.muted && "opacity-40"
              ]}
              style={"width: #{row.width}%"}
            >
            </span>
          </span>
          <span class="text-[13px] font-bold tabular-nums text-right">{row.orders}</span>
        </div>
      </div>
      <p :if={@rows == []} class="text-sm text-slate-400">No zones and no orders yet.</p>
    </.admin_card>
    """
  end

  attr :metrics, :map, required: true
  attr :zones, :list, required: true

  def buyer_costs(assigns) do
    assigns =
      assign(assigns,
        average: average_fee(assigns.metrics),
        free_zone: Enum.find(assigns.zones, & &1.free_above_pesewas),
        slowest:
          assigns.zones
          |> Enum.filter(& &1.active)
          |> Enum.max_by(& &1.estimated_days, fn -> nil end)
      )

    ~H"""
    <.admin_card class="flex flex-col gap-3">
      <div class="flex items-baseline gap-2 mb-1">
        <h3 class="text-base font-bold text-slate-900">What buyers pay</h3>
        <span class="text-xs text-slate-500">at checkout, by zone</span>
      </div>
      <.cost_row
        icon="hero-tag"
        title="Average fee paid"
        detail={"across #{paid_count(@metrics)} paid deliveries"}
      >
        {@average}
      </.cost_row>
      <.cost_row
        icon="hero-gift"
        title="Free deliveries"
        detail={free_detail(@free_zone)}
        highlight
      >
        {@metrics.free_deliveries}
      </.cost_row>
      <.cost_row
        icon="hero-clock"
        title="Longest promise"
        detail={promise_detail(@slowest)}
      >
        {if @slowest, do: "#{@slowest.estimated_days}d", else: "—"}
      </.cost_row>
      <p class="flex items-start gap-2 text-xs text-slate-400 mt-auto">
        <.icon name="hero-information-circle" class="size-3.5 shrink-0 mt-0.5" />
        Delivery times are not tracked yet, so on-time rates cannot be shown.
      </p>
    </.admin_card>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true
  attr :highlight, :boolean, default: false
  slot :inner_block, required: true

  defp cost_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-3 px-3.5 py-3 rounded-xl",
      if(@highlight, do: "bg-emerald-50", else: "bg-slate-50")
    ]}>
      <.icon
        name={@icon}
        class={["size-5 shrink-0", if(@highlight, do: "text-emerald-700", else: "text-slate-500")]}
      />
      <div class="flex-1 min-w-0">
        <p class="text-[13.5px] font-semibold text-slate-900">{@title}</p>
        <p class="text-xs text-slate-500">{@detail}</p>
      </div>
      <span class={[
        "text-lg font-extrabold tabular-nums",
        if(@highlight, do: "text-emerald-700", else: "text-slate-900")
      ]}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  defp zone_rows(zones, metrics) do
    zone_rows =
      Enum.map(zones, fn zone ->
        row = Map.get(metrics.per_zone, zone.id, %{orders: 0})

        %{
          name: zone.name,
          orders: row.orders,
          muted: !zone.active,
          tone: :zone,
          width: share(row.orders, metrics.total_orders)
        }
      end)

    unmatched =
      if metrics.unmatched.orders > 0 do
        [
          %{
            name: "No zone matched",
            orders: metrics.unmatched.orders,
            muted: false,
            tone: :warning,
            width: share(metrics.unmatched.orders, metrics.total_orders)
          }
        ]
      else
        []
      end

    Enum.sort_by(zone_rows ++ unmatched, & &1.orders, :desc)
  end

  defp share(_count, 0), do: 0
  defp share(count, total), do: round(count / total * 100)

  defp paid_count(metrics), do: max(metrics.total_orders - metrics.free_deliveries, 0)

  defp average_fee(metrics) do
    case paid_count(metrics) do
      0 -> "—"
      paid -> Currency.format_price(div(metrics.fees_collected, paid))
    end
  end

  defp free_detail(nil), do: "No zone offers free delivery yet"

  defp free_detail(zone),
    do: "#{zone.name} orders above #{Currency.format_price(zone.free_above_pesewas)}"

  defp promise_detail(nil), do: "No active zones"

  defp promise_detail(zone),
    do: "#{zone.name} · #{zone.estimated_days} #{days(zone.estimated_days)}"

  defp days(1), do: "day"
  defp days(_n), do: "days"

  defp paused_line([]), do: "All zones on"
  defp paused_line([zone]), do: "#{zone.name} is paused"
  defp paused_line(zones), do: "#{length(zones)} zones paused"

  defp unmatched_line(%{orders: 0}), do: "Every order matched a zone"
  defp unmatched_line(%{regions: regions}), do: "#{regions_line(regions)} · paid the default fee"

  defp regions_line(regions),
    do: Enum.map_join(regions, " · ", fn {region, count} -> "#{region} (#{count})" end)

  defp top_region([{region, _count} | _rest]), do: region
  defp top_region(_), do: nil
end
