defmodule EmakolaWeb.Admin.EarningsLive do
  @moduledoc """
  Merchant page showing where every cedi of earnings came from
  (money-surfaces PR-2 — the flagship page):

      /admin/earnings

  Loads Task 1's `Emakola.Payments.list_earnings_splits/2` (recipient-scoped
  earnings history — settled/partially_reversed/reversed, non-platform,
  newest-first, capped at 100 rows) in one `assign_async`, then derives total
  earned, this month, paid out, a by-source breakdown, and a recent-accruals
  feed from those same splits.

  "Payable now" is the one number that does NOT derive from that capped
  read: it loads `Emakola.Payments.list_payable_internal_splits/2` (unbounded
  — the canonical payable population) in the SAME combined async and sums
  `PaymentSplit.frozen_paid_amount/1` over it, the exact read+formula
  `payout_live`'s accrued tile uses — so the two pages' payable numbers agree
  by construction instead of by convention, even past the 100-row cap.

  Cross-store recipient rows span many source tenants (a wholesaler's
  earnings come from orders placed on OTHER stores' tenants), so the
  tenant-based membership policy cannot cover either query in one shot. Both
  reads run `authorize?: false` from inside the async — mirroring how
  `payout_live` calls `list_payable_internal_splits` — after `mount` has
  already authenticated the merchant and resolved their own store via
  `current_store`.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Payments
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Stores.Store
  alias EmakolaWeb.Helpers.Currency

  # Fixed display order for the by-source cards, independent of whichever
  # roles happen to have splits.
  @role_order [:merchant, :wholesaler, :dropshipper, :credit_partner]
  @feed_limit 20

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{} = store ->
        store_id = store.id

        {:ok,
         socket
         |> assign(:page_title, "Earnings")
         |> assign(:active_nav, :earnings)
         |> assign(:currency, store.currency || "GHS")
         |> assign_async(:earnings, fn -> load_earnings(store_id) end)}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  # ── The earnings picture ────────────────────────────────────────────

  defp load_earnings(store_id) do
    # total_earned / this_month / paid_out derive from this capped
    # (100-row) recipient-scoped history read — a recent-history window by
    # design (see PR body); revisit when any store approaches 100 splits.
    {:ok, splits} = Payments.list_earnings_splits(store_id, authorize?: false)

    # payable_now does NOT derive from the capped read above — it loads the
    # unbounded canonical payable population instead, so it can never
    # diverge from payout_live's accrued tile past the 100-row cap.
    {:ok, payable_splits} = Payments.list_payable_internal_splits(store_id, authorize?: false)

    source_names =
      splits
      |> Enum.map(& &1.store_id)
      |> Enum.reject(&(&1 == store_id))
      |> Enum.uniq()
      |> fetch_source_names()

    active = Enum.reject(splits, &(&1.status == :reversed))
    today = DateTime.to_date(DateTime.utc_now())

    {:ok,
     %{
       earnings: %{
         total_earned: sum_frozen(active),
         this_month: active |> Enum.filter(&this_month?(&1.inserted_at, today)) |> sum_frozen(),
         payable_now: sum_frozen(payable_splits),
         paid_out: paid_out(splits),
         by_role: by_role_groups(active, store_id, source_names),
         feed: feed_rows(splits, store_id, source_names)
       }
     }}
  end

  defp fetch_source_names([]), do: %{}

  defp fetch_source_names(ids) do
    Store
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1.name})
  end

  # THE freeze formula lives on PaymentSplit — every sum below reuses it (or
  # the already-frozen `paid_amount`) rather than re-deriving money math here.
  defp sum_frozen(splits),
    do: splits |> Enum.map(&PaymentSplit.frozen_paid_amount/1) |> Enum.sum()

  defp this_month?(%DateTime{} = dt, %Date{} = today) do
    date = DateTime.to_date(dt)
    date.year == today.year and date.month == today.month
  end

  defp paid_out(splits) do
    splits
    |> Enum.filter(&(not is_nil(&1.paid_out_at)))
    |> Enum.map(&(&1.paid_amount || 0))
    |> Enum.sum()
  end

  # Per-role cards — count via total only; the :wholesaler ("resale") card
  # additionally breaks its total down by the source store whose stock was
  # resold, since one store can resell for several different wholesalers.
  defp by_role_groups(active, store_id, source_names) do
    by_role = Enum.group_by(active, & &1.role)

    @role_order
    |> Enum.filter(&Map.has_key?(by_role, &1))
    |> Enum.map(fn role ->
      group = Map.fetch!(by_role, role)

      %{
        role: role,
        total: sum_frozen(group),
        sources:
          if role == :wholesaler do
            source_subtotals(group, store_id, source_names)
          else
            []
          end
      }
    end)
  end

  defp source_subtotals(group, store_id, source_names) do
    group
    |> Enum.group_by(& &1.store_id)
    |> Enum.map(fn {source_store_id, rows} ->
      %{
        source_name: source_name(source_store_id, store_id, source_names),
        total: sum_frozen(rows)
      }
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp source_name(recipient_id, recipient_id, _names), do: "you"

  defp source_name(source_id, _recipient_id, names),
    do: Map.get(names, source_id, "another store")

  # Recent accruals — order-less splits (susu contributions have no order)
  # render the same as any other row: date, net, source label.
  defp feed_rows(splits, store_id, source_names) do
    splits
    |> Enum.take(@feed_limit)
    |> Enum.map(fn split ->
      %{
        id: split.id,
        inserted_at: split.inserted_at,
        net: PaymentSplit.frozen_paid_amount(split),
        label: accrual_label(split.role, source_name(split.store_id, store_id, source_names))
      }
    end)
  end

  defp accrual_label(:merchant, _source), do: "Your sale"
  defp accrual_label(:wholesaler, source), do: "Resale of your stock by #{source}"
  defp accrual_label(:dropshipper, _source), do: "Dropship margin"
  defp accrual_label(:credit_partner, _source), do: "Credit repayment"

  defp role_title(:merchant), do: "Your sales"
  defp role_title(:wholesaler), do: "Resales of your stock"
  defp role_title(:dropshipper), do: "Dropship margin"
  defp role_title(:credit_partner), do: "Credit repayment"

  defp format_accrual_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_accrual_date(_), do: "—"

  # ── Render ──────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div id="earnings-page" class="mx-auto max-w-6xl space-y-8 px-4 py-8 sm:px-6 lg:px-8">
      <header class="overflow-hidden rounded-3xl bg-slate-950 px-6 py-8 text-white shadow-xl sm:px-10">
        <div class="max-w-2xl">
          <span class="inline-flex items-center gap-2 rounded-full bg-emerald-400/10 px-3 py-1 text-xs font-semibold text-emerald-300 ring-1 ring-emerald-400/20">
            <.icon name="hero-banknotes" class="size-4" /> Earnings
          </span>
          <h1 class="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">
            Every cedi, traced to its source
          </h1>
          <p class="mt-3 max-w-xl text-sm leading-6 text-slate-300 sm:text-base">
            Your own sales, resold stock, dropship margin, credit repayments —
            see exactly where your earnings came from.
          </p>
        </div>
      </header>

      <.async_result :let={earnings} assign={@earnings}>
        <:loading>
          <div id="earnings-loading" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div id="earnings-tile-total">
              <.money_tile
                label="Total earned"
                icon="hero-banknotes"
                icon_class="text-sky-600"
                icon_bg="bg-sky-50"
                state={:loading}
              />
            </div>
            <div id="earnings-tile-month">
              <.money_tile
                label="This month"
                icon="hero-calendar"
                icon_class="text-blue-600"
                icon_bg="bg-blue-50"
                state={:loading}
              />
            </div>
            <div id="earnings-tile-payable">
              <.money_tile
                label="Payable now"
                icon="hero-clock"
                icon_class="text-emerald-600"
                icon_bg="bg-emerald-50"
                state={:loading}
              />
            </div>
            <div id="earnings-tile-paid-out">
              <.money_tile
                label="Paid out"
                icon="hero-check-circle"
                icon_class="text-slate-600"
                icon_bg="bg-slate-100"
                state={:loading}
              />
            </div>
          </div>
        </:loading>
        <:failed>
          <div id="earnings-failed" class="space-y-3">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <div id="earnings-tile-total">
                <.money_tile
                  label="Total earned"
                  icon="hero-banknotes"
                  icon_class="text-sky-600"
                  icon_bg="bg-sky-50"
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-month">
                <.money_tile
                  label="This month"
                  icon="hero-calendar"
                  icon_class="text-blue-600"
                  icon_bg="bg-blue-50"
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-payable">
                <.money_tile
                  label="Payable now"
                  icon="hero-clock"
                  icon_class="text-emerald-600"
                  icon_bg="bg-emerald-50"
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-paid-out">
                <.money_tile
                  label="Paid out"
                  icon="hero-check-circle"
                  icon_class="text-slate-600"
                  icon_bg="bg-slate-100"
                  state={:failed}
                />
              </div>
            </div>
            <p class="text-sm text-slate-500">
              Couldn't load your earnings. Refresh the page to try again.
            </p>
          </div>
        </:failed>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div id="earnings-tile-total">
            <.money_tile
              label="Total earned"
              value={Currency.format_price(earnings.total_earned, @currency)}
              icon="hero-banknotes"
              icon_class="text-sky-600"
              icon_bg="bg-sky-50"
            />
          </div>
          <div id="earnings-tile-month">
            <.money_tile
              label="This month"
              value={Currency.format_price(earnings.this_month, @currency)}
              icon="hero-calendar"
              icon_class="text-blue-600"
              icon_bg="bg-blue-50"
            />
          </div>
          <div id="earnings-tile-payable">
            <.money_tile
              label="Payable now"
              value={Currency.format_price(earnings.payable_now, @currency)}
              icon="hero-clock"
              icon_class="text-emerald-600"
              icon_bg="bg-emerald-50"
            />
          </div>
          <div id="earnings-tile-paid-out">
            <.money_tile
              label="Paid out"
              value={Currency.format_price(earnings.paid_out, @currency)}
              icon="hero-check-circle"
              icon_class="text-slate-600"
              icon_bg="bg-slate-100"
            />
          </div>
        </div>

        <div :if={earnings.feed == []} id="earnings-empty">
          <.empty_state
            icon="hero-banknotes"
            title="No earnings yet"
            description="List a product or join the supply network to start earning — every settled sale will show up here, traced back to its source."
            action_label="View your listings"
            action_path={~p"/admin/products"}
          />
        </div>

        <div
          :if={earnings.by_role != []}
          id="earnings-by-source"
          class="grid grid-cols-1 gap-4 sm:grid-cols-2"
        >
          <div
            :for={group <- earnings.by_role}
            id={"earnings-source-#{group.role}"}
            class="rounded-2xl border border-slate-200 bg-white p-5"
          >
            <h3 class="text-sm font-semibold text-slate-700">{role_title(group.role)}</h3>
            <p class="mt-1 text-xl font-bold text-slate-900">
              {Currency.format_price(group.total, @currency)}
            </p>
            <div :if={group.sources != []} class="mt-3 space-y-1 border-t border-slate-100 pt-3">
              <div :for={source <- group.sources} class="flex items-center justify-between text-sm">
                <span class="text-slate-600">{source.source_name}</span>
                <span class="font-medium text-slate-800">
                  {Currency.format_price(source.total, @currency)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div :if={earnings.feed != []} id="earnings-feed">
          <h2 class="mb-3 text-sm font-semibold text-slate-700">Recent accruals</h2>
          <div class="overflow-x-auto rounded-lg border border-slate-200 bg-white">
            <table class="min-w-full divide-y divide-slate-100">
              <thead>
                <tr class="text-left text-xs font-medium uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-2">Date</th>
                  <th class="px-4 py-2">Source</th>
                  <th class="px-4 py-2">Net</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={row <- earnings.feed}
                  id={"earnings-feed-row-#{row.id}"}
                  class="border-t border-slate-100"
                >
                  <td class="px-4 py-3 text-sm text-slate-500">
                    {format_accrual_date(row.inserted_at)}
                  </td>
                  <td class="px-4 py-3 text-sm text-slate-700">{row.label}</td>
                  <td class="px-4 py-3 text-sm font-medium tabular-nums text-slate-900">
                    {Currency.format_price(row.net, @currency)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </.async_result>
    </div>
    """
  end

  # ── Money tile: shares one stat_card shell across loading/failed/ok ──────

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :icon, :string, required: true
  attr :icon_class, :string, required: true
  attr :icon_bg, :string, required: true
  attr :state, :atom, default: :ok, values: [:ok, :loading, :failed]

  defp money_tile(%{state: :loading} = assigns) do
    ~H"""
    <.stat_card label={@label} value="" icon_bg={@icon_bg}>
      <:icon><.icon name={@icon} class={["w-[18px] h-[18px]", @icon_class]} /></:icon>
      <:delta>
        <div class="mt-2 h-7 w-24 animate-pulse rounded bg-slate-200" aria-hidden="true"></div>
        <span class="sr-only">Loading {@label}</span>
      </:delta>
    </.stat_card>
    """
  end

  defp money_tile(%{state: :failed} = assigns) do
    ~H"""
    <.stat_card label={@label} value="—" icon_bg={@icon_bg}>
      <:icon><.icon name={@icon} class={["w-[18px] h-[18px]", @icon_class]} /></:icon>
    </.stat_card>
    """
  end

  defp money_tile(assigns) do
    ~H"""
    <.stat_card label={@label} value={@value} icon_bg={@icon_bg}>
      <:icon><.icon name={@icon} class={["w-[18px] h-[18px]", @icon_class]} /></:icon>
    </.stat_card>
    """
  end
end
