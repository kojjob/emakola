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
      {results, queued} =
        approve_both_bases(store_id, socket.assigns.current_user, :payout_approved)

      {:noreply, respond_to_approval(socket, results, queued)}
    end)
  end

  def handle_event("retry_payout", %{"payout_id" => payout_id}, socket) do
    authorized(socket, fn socket ->
      # A failed payout released its balance back to outstanding, so "retry"
      # prepares a FRESH payout (new transfer_reference) for that store rather than
      # re-running the dead one — Paystack rejects a reused reference.
      case Emakola.Payments.get_payout(payout_id, authorize?: false) do
        {:ok, %{store_id: store_id}} ->
          {_results, queued} =
            approve_both_bases(store_id, socket.assigns.current_user, :payout_retried)

          if queued == [] do
            {:noreply, put_flash(socket, :error, "Nothing outstanding to retry for this store.")}
          else
            {:noreply, socket |> load() |> put_flash(:info, "Payout retry queued.")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Nothing outstanding to retry for this store.")}
      end
    end)
  end

  # Prepares BOTH payout bases and, for each one that succeeds, enqueues +
  # audits it IMMEDIATELY — before the next basis is even prepared. This
  # matters: if prepare_internal_payout/1 were to raise (e.g. its paid_amount
  # drift tripwire) AFTER prepare_payout/1 had already committed a pending
  # payout, a batched "prepare both, then enqueue both" flow would strand that
  # first payout — claimed out of the backlog, but never enqueued or audited,
  # and unreachable by the :failed-only retry button. Preparing+processing one
  # basis at a time means the first payout's enqueue/audit (both already
  # committed, independent writes) survive even if the second basis blows up.
  defp approve_both_bases(store_id, actor, action) do
    approval_ref = generate_approval_ref()

    payments_result =
      process_basis(
        :payments,
        PayoutService.prepare_payout(store_id),
        actor,
        store_id,
        action,
        approval_ref
      )

    allocations_result =
      process_basis(
        :allocations,
        PayoutService.prepare_internal_payout(store_id),
        actor,
        store_id,
        action,
        approval_ref
      )

    results = [{:payments, payments_result}, {:allocations, allocations_result}]
    queued = for {_basis, {:ok, payout}} <- results, do: payout

    {results, queued}
  end

  # Shared id stamped into both bases' `metadata["approval_ref"]` so finance
  # can see they came from the same approval click, without ever touching
  # amount/status — see Payout's `stamp_approval_ref`.
  defp generate_approval_ref, do: "appr_" <> String.slice(Ecto.UUID.generate(), -8, 8)

  defp process_basis(_basis, {:ok, payout}, actor, store_id, action, approval_ref) do
    {:ok, payout} =
      Emakola.Payments.update_payout_metadata(
        payout,
        %{"approval_ref" => approval_ref},
        authorize?: false
      )

    PayoutWorker.enqueue(payout.id)

    PlatformAudit.log(action, actor, %{
      "store_id" => store_id,
      "payout_id" => payout.id,
      "amount" => payout.amount,
      "basis" => to_string(payout.basis)
    })

    {:ok, payout}
  end

  defp process_basis(
         _basis,
         {:error, _reason} = error,
         _actor,
         _store_id,
         _action,
         _approval_ref
       ),
       do: error

  # queued == [] → surface an error, preferring :no_momo_destination (it applies
  # to both bases, since they share transfer_destination/1) over :nothing_outstanding.
  # queued != [] → a single info flash with the SUMMED amount across both payouts.
  defp respond_to_approval(socket, results, [] = _queued) do
    errors = for {_basis, {:error, reason}} <- results, do: reason

    message =
      if :no_momo_destination in errors do
        "This store has no mobile money payout details set up."
      else
        "Nothing outstanding to pay out for this store."
      end

    put_flash(socket, :error, message)
  end

  defp respond_to_approval(socket, _results, queued) do
    total = queued |> Enum.map(& &1.amount) |> Enum.sum()

    socket
    |> load()
    |> put_flash(:info, "Payout of #{format_amount(total)} queued.")
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
                  <th class="px-6 py-3">Basis</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Date</th>
                  <th class="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@payouts == []}>
                  <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">
                    No payouts yet.
                  </td>
                </tr>
                <tr :for={payout <- @payouts} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(payout.store && payout.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">{format_amount(payout.amount)}</td>
                  <td class="px-6 py-4 text-sm text-gray-500">{payout.basis}</td>
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
    major = cents |> div(100) |> Emakola.Money.group_thousands()
    "GHS #{major}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
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
