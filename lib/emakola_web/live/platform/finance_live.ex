defmodule EmakolaWeb.Platform.FinanceLive do
  @moduledoc """
  Read-only platform finance overview (`/platform/finance`) — the money view.

  Surfaces platform revenue (transaction fees collected), GMV, the effective
  take rate, and the outstanding merchant-payout backlog, with a per-store
  breakdown. Staff can approve a payout per store (the human-approval gate of the
  payout-execution engine): it prepares a `Payout`, stamps the covered charges,
  audits the approval, and enqueues `PayoutWorker` to disburse via Paystack.
  Distinct from `/platform/payments` (transaction ops) and `/platform/billing`
  (legacy Stripe subscriptions).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Payments.PayoutService
  alias Emakola.Payments.Workers.PayoutWorker
  alias Emakola.Platform.FinanceStats
  alias Emakola.Platform.Stats

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Finance")
      |> assign(:active_nav, :finance)

    socket =
      if connected?(socket) do
        load(socket)
      else
        assign(socket, loaded: false, stats: nil, take_rate: nil, stores: [], payouts: [])
      end

    {:ok, socket}
  end

  defp load(socket) do
    fees = FinanceStats.total_platform_fees()
    outstanding = FinanceStats.total_outstanding_payouts()
    gmv = Stats.total_gmv()

    take_rate = if gmv > 0, do: fees / gmv, else: nil

    socket
    |> assign(:loaded, true)
    |> assign(:stats, %{fees: fees, outstanding: outstanding, gmv: gmv})
    |> assign(:take_rate, take_rate)
    |> assign(:stores, FinanceStats.per_store_finance())
    |> assign(:payouts, Emakola.Payments.list_recent_payouts!(load: [:store], authorize?: false))
  end

  @impl true
  def handle_event("approve_payout", %{"store_id" => store_id}, socket) do
    authorized(socket, fn socket ->
      case PayoutService.prepare_payout(store_id) do
        {:ok, payout} ->
          PayoutWorker.enqueue(payout.id)

          PlatformAudit.log(:payout_approved, socket.assigns.current_user, %{
            "store_id" => store_id,
            "payout_id" => payout.id,
            "amount" => payout.amount
          })

          {:noreply,
           socket
           |> load()
           |> put_flash(:info, "Payout of #{format_amount(payout.amount)} queued.")}

        {:error, :nothing_outstanding} ->
          {:noreply, put_flash(socket, :error, "Nothing outstanding to pay out for this store.")}

        {:error, :no_momo_destination} ->
          {:noreply,
           put_flash(socket, :error, "This store has no mobile money payout details set up.")}
      end
    end)
  end

  def handle_event("retry_payout", %{"payout_id" => payout_id}, socket) do
    authorized(socket, fn socket ->
      # The worker re-attempts a :failed payout idempotently (same transfer_reference).
      PayoutWorker.enqueue(payout_id)

      PlatformAudit.log(:payout_retried, socket.assigns.current_user, %{"payout_id" => payout_id})

      {:noreply, socket |> load() |> put_flash(:info, "Payout retry queued.")}
    end)
  end

  # Re-check the permission against a fresh user (Iron Law: never trust mount).
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_billing) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage payouts.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Finance</h1>
        <p class="text-sm text-gray-500 mt-1">
          Platform revenue &amp; merchant payout balances across all stores
        </p>
      </div>

      <%= if @loaded == false do %>
        <div class="text-center py-16 text-gray-400">
          <p class="text-sm">Loading finance data…</p>
        </div>
      <% else %>
        <%!-- ── Revenue stat strip ─────────────────────────────────────── --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <.stat_tile
            label="Platform fees collected"
            value={format_amount(@stats.fees)}
            icon="account_balance_wallet"
            color="emerald"
          />
          <.stat_tile
            label="GMV"
            value={format_amount(@stats.gmv)}
            icon="trending_up"
            color="blue"
          />
          <.stat_tile
            label="Effective take rate"
            value={format_rate(@take_rate)}
            icon="percent"
            color="violet"
          />
          <.stat_tile
            label="Outstanding payouts"
            value={format_amount(@stats.outstanding)}
            icon="payments"
            color="amber"
          />
        </div>

        <%!-- ── Per-store breakdown ────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">By store</h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Sorted by outstanding balance — the manual-payout worklist
            </p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Fees collected</th>
                  <th class="px-6 py-3">Outstanding owed</th>
                  <th class="px-6 py-3">Payouts</th>
                  <th class="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@stores == []}>
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No finance activity yet.
                  </td>
                </tr>
                <tr :for={row <- @stores} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(row.store && row.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-emerald-700">
                    {format_amount(row.fees_collected)}
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {format_amount(row.outstanding_owed)}
                  </td>
                  <td class="px-6 py-4 text-sm">
                    <span :if={row.payouts_ready?} class={pill_class(:ready)}>Ready</span>
                    <span :if={!row.payouts_ready?} class={pill_class(:missing)}>
                      No payout set up
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-right">
                    <button
                      :if={row.outstanding_owed > 0}
                      type="button"
                      phx-click="approve_payout"
                      phx-value-store_id={row.store.id}
                      data-confirm={"Pay out #{format_amount(row.outstanding_owed)} to #{row.store.name}? This sends money to their mobile money account."}
                      class="rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700"
                    >
                      Pay out
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- ── Recent payouts ─────────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mt-8">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Recent payouts</h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Disbursements to merchants — retry any that failed
            </p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Amount</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Date</th>
                  <th class="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@payouts == []}>
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No payouts yet.
                  </td>
                </tr>
                <tr :for={payout <- @payouts} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(payout.store && payout.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">{format_amount(payout.amount)}</td>
                  <td class="px-6 py-4 text-sm">
                    <span class={payout_pill_class(payout.status)}>
                      {humanize_status(payout.status)}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-400">{date_str(payout.inserted_at)}</td>
                  <td class="px-6 py-4 text-sm text-right">
                    <button
                      :if={payout.status == :failed}
                      type="button"
                      phx-click="retry_payout"
                      phx-value-payout_id={payout.id}
                      data-confirm={"Retry the #{format_amount(payout.amount)} payout to #{(payout.store && payout.store.name) || "this store"}?"}
                      class="rounded-lg border border-amber-300 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800 hover:bg-amber-100"
                    >
                      Retry
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Private helpers ─────────────────────────────────────────────────

  defp format_amount(nil), do: "GHS 0.00"

  defp format_amount(cents) when is_integer(cents) do
    "GHS #{div(cents, 100)}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
  end

  defp format_amount(_), do: "GHS 0.00"

  defp format_rate(nil), do: "—"
  defp format_rate(rate), do: "#{Float.round(rate * 100, 1)}%"

  defp pill_class(:ready),
    do: "inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700"

  defp pill_class(:missing),
    do: "inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700"

  @pill_base "inline-flex px-2 py-0.5 rounded-full text-xs font-medium "

  defp payout_pill_class(:paid), do: @pill_base <> "bg-emerald-100 text-emerald-700"
  defp payout_pill_class(:processing), do: @pill_base <> "bg-blue-100 text-blue-700"
  defp payout_pill_class(:failed), do: @pill_base <> "bg-rose-100 text-rose-700"
  defp payout_pill_class(_pending), do: @pill_base <> "bg-gray-100 text-gray-600"

  defp humanize_status(status), do: status |> to_string() |> String.capitalize()

  defp date_str(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(_), do: "—"
end
