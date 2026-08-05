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

  Also surfaces the "Needs remediation" worklist — splits
  `PaymentSplit.release_from_payout` stamped as unreclaimable (fully reversed
  while their payout claim was in flight) — closing the gap where that flag
  had zero UI surface despite the domain code's own comment promising finance
  could find them.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Payments.PayoutService
  alias Emakola.Payments.Workers.PayoutWorker
  alias Emakola.Platform.FinanceStats
  alias Emakola.Platform.Stats
  alias EmakolaWeb.Helpers.Currency

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Finance")
      |> assign(:active_nav, :finance)
      |> assign(:expanded_store_id, nil)
      |> assign(:loaded, false)
      |> assign(:stats, nil)
      |> assign(:take_rate, nil)
      |> assign(:finance_store_ids, MapSet.new())
      |> assign(:finance_store_count, 0)
      |> assign(:payout_group_count, 0)
      |> assign(:remediation_count, 0)
      |> stream(:store_rows, [], dom_id: &"finance-store-#{&1.store.id}")
      |> stream(:payout_groups, [], dom_id: &"payout-group-#{&1.id}")
      |> stream(:remediation_rows, [], dom_id: &remediation_dom_id/1)

    socket =
      if connected?(socket) do
        load(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp load(socket) do
    fees = FinanceStats.total_platform_fees()
    outstanding = FinanceStats.total_outstanding_payouts()
    gmv = Stats.total_gmv()

    take_rate = if gmv > 0, do: fees / gmv, else: nil

    # Only the count lives in assigns (for the tile) — the worklist itself is
    # unbounded and cross-store, so it's streamed rather than held whole in
    # process memory. length/1 here is a single pass over the already-loaded
    # list, not a second query.
    remediation_rows = FinanceStats.remediation_splits()
    store_rows = FinanceStats.per_store_finance()

    payout_groups =
      Emakola.Payments.list_recent_payouts!(load: [:store], authorize?: false)
      |> payout_groups()

    socket
    |> assign(:loaded, true)
    |> assign(:stats, %{fees: fees, outstanding: outstanding, gmv: gmv})
    |> assign(:take_rate, take_rate)
    |> assign(:finance_store_ids, MapSet.new(store_rows, & &1.store.id))
    |> assign(:finance_store_count, length(store_rows))
    |> assign(:payout_group_count, length(payout_groups))
    |> assign(:remediation_count, length(remediation_rows))
    |> stream(:store_rows, store_rows, reset: true)
    |> stream(:payout_groups, payout_groups, reset: true)
    |> stream(:remediation_rows, remediation_rows, reset: true, dom_id: &remediation_dom_id/1)
  end

  defp remediation_dom_id(%{split: split}), do: "remediation-row-#{split.id}"

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

  # Assigns-toggled, JS-free expand/collapse for a per-store row's dual-basis
  # breakdown. The rows are re-fetched and re-streamed so the expanded assign
  # is reflected inside streamed children (streams do not re-render from an
  # unrelated assign change on their own).
  def handle_event("toggle_store_breakdown", %{"store_id" => store_id}, socket) do
    authorized(socket, fn socket ->
      if MapSet.member?(socket.assigns.finance_store_ids, store_id) do
        current = socket.assigns.expanded_store_id
        next = if current == store_id, do: nil, else: store_id

        {:noreply,
         socket
         |> assign(:expanded_store_id, next)
         |> reload_store_rows()}
      else
        {:noreply, socket}
      end
    end)
  end

  defp reload_store_rows(socket) do
    rows = FinanceStats.per_store_finance()

    socket
    |> assign(:finance_store_ids, MapSet.new(rows, & &1.store.id))
    |> assign(:finance_store_count, length(rows))
    |> stream(:store_rows, rows, reset: true)
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
    PayoutWorker.enqueue(payout.id)

    PlatformAudit.log(action, actor, %{
      "store_id" => store_id,
      "payout_id" => payout.id,
      "amount" => payout.amount,
      "basis" => to_string(payout.basis)
    })

    # Cosmetic grouping only — stamped AFTER the payout is already enqueued
    # and audited, so a stamping failure can never strand it (the exact
    # stranding shape this function's own docstring exists to prevent).
    # Log-and-continue: an unstamped payout just renders ungrouped, which is
    # honest, rather than raising and losing a payout that already moved.
    stamped_payout =
      case Emakola.Payments.update_payout_metadata(
             payout,
             %{"approval_ref" => approval_ref},
             authorize?: false
           ) do
        {:ok, stamped} ->
          stamped

        {:error, reason} ->
          Logger.warning(
            "[FinanceLive] failed to stamp approval_ref on payout #{payout.id}: #{inspect(reason)}"
          )

          payout
      end

    {:ok, stamped_payout}
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
    |> put_flash(:info, "Payout of #{Currency.format_price(total)} queued.")
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
      <.page_header
        title="Finance"
        subtitle="Platform revenue &amp; merchant payout balances across all stores"
      />

      <%= if @loaded == false do %>
        <div class="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-8" aria-hidden="true">
          <div :for={_tile <- 1..5} class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="h-4 w-24 rounded bg-gray-200 animate-pulse"></div>
            <div class="mt-4 h-8 w-28 rounded bg-gray-200 animate-pulse"></div>
          </div>
        </div>
        <span class="sr-only">Loading finance data…</span>
      <% else %>
        <%!-- ── Revenue stat strip ─────────────────────────────────────── --%>
        <div class="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
          <.stat_tile
            label="Platform fees collected"
            value={Currency.format_price(@stats.fees)}
            icon="account_balance_wallet"
            color="emerald"
          />
          <.stat_tile
            label="GMV"
            value={Currency.format_price(@stats.gmv)}
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
            value={Currency.format_price(@stats.outstanding)}
            icon="payments"
            color="amber"
          />
          <.stat_tile
            id="remediation-count"
            label="Needs remediation"
            value={@remediation_count}
            icon="flag"
            color="rose"
          />
        </div>

        <%!-- ── Per-store breakdown ────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">By store</h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Sorted by outstanding balance — the manual-payout worklist. Click a store to see
              its gateway vs. ledger breakdown.
            </p>
          </div>
          <.platform_empty_state
            :if={@finance_store_count == 0}
            title="No finance activity yet"
            description="Once a store collects fees or accrues an outstanding balance, it'll show up here."
            icon="hero-banknotes"
          />
          <div class={["overflow-x-auto", @finance_store_count == 0 && "hidden"]}>
            <table
              id="finance-store-rows"
              phx-update="stream"
              data-count={@finance_store_count}
              class="w-full"
            >
              <thead id="finance-store-rows-head">
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Fees collected</th>
                  <th class="px-6 py-3">Outstanding owed</th>
                  <th class="px-6 py-3">Payouts</th>
                  <th class="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody
                :for={{dom_id, row} <- @streams.store_rows}
                id={dom_id}
                class="divide-y divide-gray-100"
              >
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    <button
                      type="button"
                      phx-click="toggle_store_breakdown"
                      phx-value-store_id={row.store.id}
                      class="flex items-center gap-1 hover:text-emerald-700"
                    >
                      <span class="material-symbols-outlined text-base text-gray-400">
                        {if @expanded_store_id == row.store.id,
                          do: "expand_more",
                          else: "chevron_right"}
                      </span>
                      {row.store.name}
                    </button>
                  </td>
                  <td class="px-6 py-4 text-sm text-emerald-700">
                    {Currency.format_price(row.fees_collected)}
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {Currency.format_price(row.outstanding_owed)}
                  </td>
                  <td class="px-6 py-4 text-sm">
                    <.severity_pill
                      tone={readiness_tone(row.payouts_ready?)}
                      label={readiness_label(row.payouts_ready?)}
                    />
                  </td>
                  <td class="px-6 py-4 text-sm text-right">
                    <button
                      :if={row.outstanding_owed > 0}
                      type="button"
                      disabled={!row.payouts_ready?}
                      title={
                        if row.payouts_ready?,
                          do: nil,
                          else: "Add a mobile money payout destination for this store first"
                      }
                      phx-click="approve_payout"
                      phx-value-store_id={row.store.id}
                      data-confirm={both_bases_confirm(row)}
                      class={[
                        "rounded-lg px-3 py-1.5 text-xs font-medium",
                        if(row.payouts_ready?,
                          do: "bg-emerald-600 text-white hover:bg-emerald-700",
                          else: "bg-gray-100 text-gray-400 cursor-not-allowed"
                        )
                      ]}
                    >
                      Pay out
                    </button>
                  </td>
                </tr>
                <tr
                  :if={@expanded_store_id == row.store.id}
                  id={"store-breakdown-#{row.store.id}"}
                  class="bg-gray-50"
                >
                  <td colspan="5" class="px-6 py-4 text-sm text-gray-600">
                    <div class="flex flex-wrap gap-6">
                      <div>
                        <span class="text-xs uppercase tracking-wide text-gray-400">
                          Gateway (legacy)
                        </span>
                        <p class="font-semibold text-gray-900">
                          {Currency.format_price(row.legacy_owed)}
                        </p>
                      </div>
                      <div>
                        <span class="text-xs uppercase tracking-wide text-gray-400">
                          Ledger (internal)
                        </span>
                        <p class="font-semibold text-gray-900">
                          {Currency.format_price(row.internal_owed)}
                        </p>
                      </div>
                    </div>
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
              Disbursements to merchants — retry any that failed. Payouts born of one approval
              click are grouped together.
            </p>
          </div>
          <.platform_empty_state
            :if={@payout_group_count == 0}
            title="No payouts yet"
            description="Approved payouts will show up here."
            icon="hero-arrow-path"
          />
          <div class={["overflow-x-auto", @payout_group_count == 0 && "hidden"]}>
            <table
              id="finance-payout-groups"
              phx-update="stream"
              data-count={@payout_group_count}
              class="w-full"
            >
              <thead id="finance-payout-groups-head">
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Amount</th>
                  <th class="px-6 py-3">Basis</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Date</th>
                  <th class="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody
                :for={{dom_id, group} <- @streams.payout_groups}
                id={dom_id}
                class="divide-y divide-gray-100"
              >
                <tr :if={group.ref} class="bg-indigo-50/60">
                  <td colspan="6" class="px-6 py-2 text-xs font-medium text-indigo-700">
                    <span class="material-symbols-outlined text-sm align-middle mr-1">link</span>
                    Approved together · <span class="font-mono">{group.ref}</span>
                  </td>
                </tr>
                <tr :for={payout <- group.payouts} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(payout.store && payout.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">
                    {Currency.format_price(payout.amount)}
                  </td>
                  <td class="px-6 py-4 text-sm">
                    <.severity_pill tone={basis_tone(payout.basis)} label={basis_label(payout.basis)} />
                  </td>
                  <td class="px-6 py-4 text-sm">
                    <.severity_pill
                      tone={status_tone(payout.status)}
                      label={status_label(payout.status)}
                    />
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-400">{date_str(payout.inserted_at)}</td>
                  <td class="px-6 py-4 text-sm text-right">
                    <button
                      :if={payout.status == :failed}
                      type="button"
                      phx-click="retry_payout"
                      phx-value-payout_id={payout.id}
                      data-confirm={"Retry the #{Currency.format_price(payout.amount)} payout to #{(payout.store && payout.store.name) || "this store"}?"}
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

        <%!-- ── Needs remediation ──────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mt-8">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Needs remediation</h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Splits fully reversed while their payout claim was in flight — the platform holds
              the shortfall and can no longer claw it back automatically. Follow up manually.
            </p>
          </div>
          <.platform_empty_state
            :if={@remediation_count == 0}
            title="Nothing needs remediation"
            description="Flagged splits will show up here for manual follow-up."
            icon="hero-check-circle"
          />
          <%!-- The stream container stays mounted regardless of @remediation_count
          (a known LiveView streams gotcha: conditionally rendering it with :if
          would tear it down and corrupt future stream diffs) — hidden via CSS
          instead, matching the empty state's visibility exactly. --%>
          <div class={["overflow-x-auto", @remediation_count == 0 && "hidden"]}>
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Split amount</th>
                  <th class="px-6 py-3">Reversed</th>
                  <th class="px-6 py-3">Recovered + reserved</th>
                  <th class="px-6 py-3">Flagged</th>
                  <th class="px-6 py-3">Status</th>
                </tr>
              </thead>
              <tbody id="remediation-rows" phx-update="stream" class="divide-y divide-gray-100">
                <tr
                  :for={{dom_id, row} <- @streams.remediation_rows}
                  id={dom_id}
                  class="hover:bg-gray-50 transition-colors"
                >
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(row.store && row.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">
                    {Currency.format_price(row.split.amount)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">
                    {Currency.format_price(row.split.reversed_amount)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900">
                    {Currency.format_price(
                      row.split.recovered_amount + row.split.reserved_recovery_amount
                    )}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-400">{date_str(row.split.updated_at)}</td>
                  <td class="px-6 py-4 text-sm">
                    <.severity_pill tone="rose" label="Needs remediation" />
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

  defp format_rate(nil), do: "—"
  defp format_rate(rate), do: "#{Float.round(rate * 100, 1)}%"

  defp both_bases_confirm(row) do
    "Pay out #{Currency.format_price(row.legacy_owed)} (gateway) and " <>
      "#{Currency.format_price(row.internal_owed)} (ledger) to #{row.store.name}? " <>
      "This sends money to their mobile money account."
  end

  defp readiness_tone(true), do: "emerald"
  defp readiness_tone(false), do: "amber"

  defp readiness_label(true), do: "Ready"
  defp readiness_label(false), do: "No payout set up"

  defp basis_tone(:allocations), do: "violet"
  defp basis_tone(_payments), do: "blue"

  defp basis_label(:allocations), do: "Ledger"
  defp basis_label(_payments), do: "Gateway"

  defp status_tone(:paid), do: "emerald"
  defp status_tone(:processing), do: "blue"
  defp status_tone(:failed), do: "rose"
  defp status_tone(:reversed), do: "amber"
  defp status_tone(_pending), do: "slate"

  defp status_label(status), do: status |> to_string() |> String.capitalize()

  # Groups payouts sharing a non-nil metadata["approval_ref"], wherever they
  # fall in the (newest-first) list — NOT by adjacency. The two payouts one
  # approve click creates are usually enqueued back-to-back, but a concurrent
  # approval's payout can land between them, which would silently split the
  # group under an adjacency-based grouping (e.g. Enum.chunk_by). Instead,
  # this walks the list once, keyed by ref, and orders groups by each ref's
  # FIRST appearance — a ref-less payout is always its own singleton group at
  # its own position. A ref shared by only one payout in this list (its
  # partner basis failed, or fell outside the page) renders same as an
  # ungrouped row: the "Approved together" badge only appears once 2+ payouts
  # actually land in the same group.
  defp payout_groups(payouts) do
    {order, by_key} =
      Enum.reduce(payouts, {[], %{}}, fn payout, {order, by_key} ->
        key = payout.metadata["approval_ref"] || make_ref()

        if Map.has_key?(by_key, key) do
          {order, Map.update!(by_key, key, &[payout | &1])}
        else
          {[key | order], Map.put(by_key, key, [payout])}
        end
      end)

    order
    |> Enum.reverse()
    |> Enum.map(fn key ->
      group = Enum.reverse(by_key[key])
      ref = if is_binary(key) and length(group) > 1, do: key, else: nil
      id = "payout-#{List.first(group).id}"
      %{id: id, ref: ref, payouts: group}
    end)
  end

  defp date_str(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(_), do: "—"
end
