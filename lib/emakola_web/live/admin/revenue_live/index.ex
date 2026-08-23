defmodule EmakolaWeb.Admin.RevenueLive.Index do
  @moduledoc """
  Revenue analytics for the merchant admin.

      /admin/revenue

  Every figure here is this store's own money, read live. The page previously
  shipped `assign_placeholder_data/1` — invented KPIs, six invented customers
  and three invented payouts — which real merchants were being shown.

  Definitions, chosen so the money pages cannot contradict each other:

    * **Gross** is successful payments in the period — the same read
      `/admin/payments` sums for its volume tile.
    * **Platform fees** are `:platform` PaymentSplit rows, `status != :pending`,
      netted by `amount - reversed_amount`. That is the definition
      `Emakola.Platform.FinanceStats` uses platform-side, so the merchant's
      figure and the platform's agree by construction. A refund gives the fee
      back, so counting gross would overstate what the merchant paid.
    * **Net** is gross minus those fees, derived and never stored.
    * **Pending payouts** is `PayoutService.outstanding_payments/1` — the same
      call `/admin/payouts` uses for its accrued tile.

  Two panels the old page showed cannot be built from this schema and were
  removed rather than faked: a payment-instrument split (MoMo / card / COD —
  `Payment` carries only `gateway`), and a payout schedule ("Next payout:
  22 Mar" — nothing schedules payouts).
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  alias Emakola.Payments.Payment
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.PayoutService

  @periods ~w(today week month year)

  # Rows in the transactions table. The KPI sums are unbounded; only the table
  # is capped, so a busy store's tiles stay correct.
  @table_limit 100

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Revenue",
        active_nav: :revenue,
        store_id: get_store_id(socket),
        period: "month",
        periods: @periods
      )
      |> load_revenue()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) when period in @periods do
    {:noreply, socket |> assign(period: period) |> load_revenue()}
  end

  def handle_event("change_period", _params, socket), do: {:noreply, socket}

  # ── Loading ─────────────────────────────────────────────────────────
  #
  # One read of the period, then every figure is derived in Elixir. Separate
  # aggregate queries for numbers that must agree with each other is how a
  # dashboard starts contradicting itself.

  defp load_revenue(socket) do
    %{store_id: store_id, period: period} = socket.assigns

    payments = fetch_payments(store_id, period)
    fee_by_payment = fetch_platform_fees(store_id, period)
    gross = gross_total(payments)
    fees = fee_by_payment |> Map.values() |> Enum.sum()

    assign(socket,
      kpi: %{
        gross_revenue: gross,
        platform_fees: fees,
        net_revenue: gross - fees,
        pending_payouts: pending_payouts(store_id)
      },
      revenue_change: revenue_change(store_id, period, gross),
      revenue_chart: build_revenue_chart(payments, period),
      gateways: build_gateways(payments),
      transactions: build_transactions(payments, fee_by_payment),
      payouts: fetch_payouts(store_id)
    )
  end

  defp fetch_payments(nil, _period), do: []

  defp fetch_payments(store_id, period) do
    Payment
    |> Ash.Query.filter(store_id == ^store_id)
    |> period_filter(period)
    |> Ash.Query.load(:order)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error("[revenue_live] loading payments raised: #{Exception.message(exception)}")
      []
  end

  # Fees per payment, so the table's Fee/Net columns and the KPI tile come from
  # one read of the same rows.
  defp fetch_platform_fees(nil, _period), do: %{}

  defp fetch_platform_fees(store_id, period) do
    PaymentSplit
    |> Ash.Query.filter(store_id == ^store_id and role == :platform and status != :pending)
    |> period_filter(period)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.payment_id, &1.amount - &1.reversed_amount})
  rescue
    exception ->
      Logger.error("[revenue_live] loading platform fees raised: #{Exception.message(exception)}")
      %{}
  end

  defp pending_payouts(nil), do: 0

  defp pending_payouts(store_id) do
    store_id
    |> PayoutService.outstanding_payments()
    |> Enum.map(&(&1.payable_amount || &1.amount))
    |> Enum.sum()
  rescue
    exception ->
      Logger.error("[revenue_live] loading outstanding raised: #{Exception.message(exception)}")
      0
  end

  defp fetch_payouts(nil), do: []

  defp fetch_payouts(store_id) do
    case Emakola.Payments.list_store_payouts(store_id, authorize?: false) do
      {:ok, payouts} -> payouts
      _ -> []
    end
  end

  defp gross_total(payments) do
    payments
    |> Enum.filter(&(&1.status == :success))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  # Period-over-period, from the same definition of gross. Nil when there is no
  # previous period to compare against — never a fabricated percentage.
  defp revenue_change(nil, _period, _gross), do: nil
  defp revenue_change(_store_id, "year", _gross), do: nil

  defp revenue_change(store_id, period, gross) do
    {from, to} = previous_window(period)

    previous =
      Payment
      |> Ash.Query.filter(store_id == ^store_id and inserted_at >= ^from and inserted_at < ^to)
      |> Ash.read!(authorize?: false)
      |> gross_total()

    if previous > 0 do
      Float.round((gross - previous) / previous * 100, 1)
    end
  rescue
    exception ->
      Logger.error("[revenue_live] previous period raised: #{Exception.message(exception)}")
      nil
  end

  # ── Period windows ──────────────────────────────────────────────────

  @period_days %{"today" => 0, "week" => 6, "month" => 29, "year" => 364}

  defp period_filter(query, period) do
    Ash.Query.filter(query, inserted_at >= ^period_start(period))
  end

  defp period_start(period) do
    Date.utc_today()
    |> Date.add(-Map.fetch!(@period_days, period))
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp previous_window(period) do
    days = Map.fetch!(@period_days, period) + 1
    start = period_start(period)
    {DateTime.add(start, -days, :day), start}
  end

  # ── Derived shapes ──────────────────────────────────────────────────

  @chart_step_threshold 45

  # Successful money over the period, gaps filled so a quiet day reads as zero
  # rather than closing the line across it. Long spans bucket weekly, which
  # keeps the axis readable without hiding anything.
  defp build_revenue_chart(payments, period) do
    days = Map.fetch!(@period_days, period) + 1
    step = if days > @chart_step_threshold, do: 7, else: 1
    today = Date.utc_today()

    by_date =
      payments
      |> Enum.filter(&(&1.status == :success))
      |> Enum.group_by(&DateTime.to_date(&1.inserted_at))

    today
    |> Date.add(-(days - 1))
    |> Date.range(today, step)
    |> Enum.map(fn bucket_start ->
      bucket_end = Date.add(bucket_start, step - 1)

      total =
        by_date
        |> Enum.filter(fn {date, _rows} ->
          Date.compare(date, bucket_start) != :lt and Date.compare(date, bucket_end) != :gt
        end)
        |> Enum.flat_map(fn {_date, rows} -> Enum.map(rows, & &1.amount) end)
        |> Enum.sum()

      {Calendar.strftime(bucket_start, "%b %d"), total}
    end)
    |> Enum.unzip()
    |> then(fn {labels, values} -> %{labels: labels, values: values} end)
  end

  # Gateway, not instrument. `Payment` has no MoMo/card/COD field, so the old
  # payment-method panel could not have been anything but invented.
  defp build_gateways(payments) do
    payments
    |> Enum.filter(&(&1.status == :success))
    |> Enum.group_by(& &1.gateway)
    |> Enum.map(fn {gateway, rows} ->
      %{
        gateway: gateway,
        label: gateway_label(gateway),
        total: Enum.sum(Enum.map(rows, & &1.amount))
      }
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp gateway_label(:paystack), do: "Paystack"
  defp gateway_label(:hubtel), do: "Hubtel"
  defp gateway_label(other), do: other |> to_string() |> String.capitalize()

  defp build_transactions(payments, fee_by_payment) do
    payments
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.take(@table_limit)
    |> Enum.map(fn payment ->
      fee = Map.get(fee_by_payment, payment.id, 0)

      %{
        date: Calendar.strftime(payment.inserted_at, "%d/%m/%Y"),
        order_number: payment.order && payment.order.order_number,
        customer: payment.customer_email,
        amount: payment.amount,
        gateway: gateway_label(payment.gateway),
        fee: fee,
        net: payment.amount - fee,
        status: payment.status
      }
    end)
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  # ── Render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        title="Revenue"
        subtitle="Track your earnings and payouts"
        icon="hero-chart-bar"
      >
        <div class="flex bg-slate-100 rounded-control p-1">
          <button
            :for={p <- @periods}
            phx-click="change_period"
            phx-value-period={p}
            class={[
              "px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-all",
              if(@period == p,
                do: "bg-surface text-primary shadow-sm",
                else: "text-slate-500 hover:text-slate-700"
              )
            ]}
          >
            {period_label(p)}
          </button>
        </div>
      </.admin_page_header>

      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <.stat_card
          id="stat-revenue-gross"
          label="Money in"
          value={format_cedis(@kpi.gross_revenue)}
          tone={:accent}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <.change_note change={@revenue_change} />
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-revenue-fees"
          label="Makola's share"
          value={format_cedis(@kpi.platform_fees)}
          tone={:warning}
        >
          <:icon><.icon name="hero-receipt-percent" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Taken from money in</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-revenue-net"
          label="Your share"
          value={format_cedis(@kpi.net_revenue)}
          tone={:success}
        >
          <:icon><.icon name="hero-wallet" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Money in, less the share</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-revenue-pending"
          label="Waiting to be sent"
          value={format_cedis(@kpi.pending_payouts)}
          tone={:info}
        >
          <:icon><.icon name="hero-clock" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Not paid out yet</p>
          </:delta>
        </.stat_card>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="lg:col-span-2">
          <.admin_card padding={:none} class="p-5">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-arrow-trending-up" class="size-5 text-primary" />
              <h2 class="text-base font-bold text-slate-800">Money over time</h2>
            </div>
            <div class="h-64">
              <canvas
                id="revenue-daily-chart"
                phx-hook="ChartHook"
                phx-update="ignore"
                data-chart-type="gmv-line"
                data-chart-data={Jason.encode!(@revenue_chart)}
                class="w-full h-full"
              />
            </div>
          </.admin_card>
        </div>

        <.admin_card :if={@gateways != []} padding={:none} class="p-5">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-chart-pie" class="size-5 text-primary" />
            <h2 class="text-base font-bold text-slate-800">Who took the money</h2>
          </div>
          <div class="relative h-44">
            <canvas
              id="revenue-gateway-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="provider-donut"
              data-chart-data={Jason.encode!(gateway_chart(@gateways))}
              class="w-full h-full"
            />
          </div>
          <div class="divide-y divide-slate-100 mt-3">
            <div
              :for={{gateway, index} <- Enum.with_index(@gateways)}
              class="flex items-center gap-3 py-2.5"
            >
              <span class={["w-3 h-3 rounded-full shrink-0", gateway_dot(index)]} />
              <p class="flex-1 text-sm font-semibold text-slate-900">{gateway.label}</p>
              <p class="text-sm font-bold text-slate-900 tabular-nums">
                {format_cedis(gateway.total)}
              </p>
            </div>
          </div>
        </.admin_card>
      </div>

      <.admin_card padding={:none} class="p-5">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-list-bullet" class="size-5 text-primary" />
          <h2 class="text-base font-bold text-slate-800">Every payment</h2>
        </div>

        <.empty_state
          :if={@transactions == []}
          icon="hero-banknotes"
          tone={:info}
          title="No money yet"
          description="Payments will show here as they come in"
        />

        <div :if={@transactions != []} class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-100">
            <thead>
              <tr class="text-left text-xs font-semibold uppercase tracking-wide text-slate-400">
                <th class="px-3 py-3">Date</th>
                <th class="px-3 py-3">Order</th>
                <th class="px-3 py-3">Customer</th>
                <th class="px-3 py-3">Amount</th>
                <th class="px-3 py-3">Through</th>
                <th class="px-3 py-3">Share</th>
                <th class="px-3 py-3">Yours</th>
                <th class="px-3 py-3">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={txn <- @transactions}>
                <td class="px-3 py-3 text-sm text-slate-500">{txn.date}</td>
                <td class="px-3 py-3 text-sm font-medium text-slate-700">
                  {txn.order_number || "—"}
                </td>
                <td class="px-3 py-3 text-sm text-slate-700">{txn.customer || "—"}</td>
                <td class="px-3 py-3 text-sm font-semibold text-slate-900 tabular-nums">
                  {format_cedis(txn.amount)}
                </td>
                <td class="px-3 py-3 text-sm text-slate-500">{txn.gateway}</td>
                <td class="px-3 py-3 text-sm text-slate-500 tabular-nums">
                  {format_cedis(txn.fee)}
                </td>
                <td class="px-3 py-3 text-sm font-semibold text-slate-900 tabular-nums">
                  {format_cedis(txn.net)}
                </td>
                <td class="px-3 py-3">
                  <.status_badge status={txn.status} variant={:payment} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </.admin_card>

      <.admin_card padding={:none} class="p-5">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-paper-airplane" class="size-5 text-primary" />
          <h2 class="text-base font-bold text-slate-800">Money sent to you</h2>
        </div>

        <.empty_state
          :if={@payouts == []}
          icon="hero-paper-airplane"
          title="Nothing sent yet"
          description="Payouts will show here once Makola sends your money"
        />

        <div :if={@payouts != []} class="divide-y divide-slate-100">
          <div :for={payout <- @payouts} class="flex items-center gap-4 py-3">
            <div class="w-11 h-11 rounded-control bg-success-soft flex items-center justify-center shrink-0">
              <.icon name="hero-paper-airplane" class="size-5 text-success" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-slate-900">
                {format_cedis(payout.amount)}
              </p>
              <p class="text-xs text-slate-500">{format_date(payout.inserted_at)}</p>
            </div>
            <.status_badge status={payout.status} variant={:payout} />
          </div>
        </div>
      </.admin_card>
    </div>
    """
  end

  attr :change, :float, default: nil

  defp change_note(%{change: nil} = assigns) do
    ~H"""
    <p class="text-sm text-slate-500">No earlier period to compare</p>
    """
  end

  defp change_note(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <.icon
        name={if @change >= 0, do: "hero-arrow-up", else: "hero-arrow-down"}
        class={["size-4", if(@change >= 0, do: "text-success", else: "text-danger")]}
      />
      <span class={[
        "text-sm font-semibold",
        if(@change >= 0, do: "text-success", else: "text-danger")
      ]}>
        {abs(@change)}%
      </span>
      <span class="text-sm text-slate-500">vs before</span>
    </div>
    """
  end

  defp gateway_chart(gateways) do
    %{labels: Enum.map(gateways, & &1.label), values: Enum.map(gateways, & &1.total)}
  end

  # Positionally matched to PROVIDER_COLORS in assets/js/hooks/chart_hook.js.
  defp gateway_dot(0), do: "bg-success"
  defp gateway_dot(1), do: "bg-info"
  defp gateway_dot(2), do: "bg-warning"
  defp gateway_dot(_), do: "bg-slate-500"

  defp period_label("today"), do: "Today"
  defp period_label("week"), do: "This Week"
  defp period_label("month"), do: "This Month"
  defp period_label("year"), do: "This Year"

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y")
  defp format_date(_), do: "—"

  defp format_cedis(amount) when is_integer(amount) do
    major = amount |> div(100) |> abs() |> Emakola.Money.group_thousands()
    minor = rem(abs(amount), 100)
    sign = if amount < 0, do: "-", else: ""

    "GH₵ #{sign}#{major}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end

  defp format_cedis(_), do: "GH₵ 0.00"
end
