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
  @role_order [:merchant, :wholesaler, :dropshipper, :credit_partner, :affiliate]
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
  defp accrual_label(:affiliate, _source), do: "Commission you paid"

  defp role_title(:merchant), do: "Your sales"
  defp role_title(:wholesaler), do: "Resales of your stock"
  defp role_title(:dropshipper), do: "Dropship margin"
  defp role_title(:credit_partner), do: "Credit repayment"
  defp role_title(:affiliate), do: "Commission you paid"

  defp format_accrual_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_accrual_date(_), do: "—"

  defp role_icon(:merchant), do: "hero-shopping-bag"
  defp role_icon(:wholesaler), do: "hero-building-storefront"
  defp role_icon(:dropshipper), do: "hero-truck"
  defp role_icon(:credit_partner), do: "hero-credit-card"
  defp role_icon(:affiliate), do: "hero-megaphone"

  # Slice colours, positional, mirroring PROVIDER_COLORS in
  # assets/js/hooks/chart_hook.js — a source's card wears the colour of its
  # slice, so the ring and the cards read as one picture. Chart.js cannot read
  # CSS custom properties, which is why the two lists are kept in step by hand.
  @slice_tiles ["bg-emerald-500", "bg-blue-600", "bg-amber-500", "bg-slate-500"]

  defp slice_tile(index), do: Enum.at(@slice_tiles, rem(index, length(@slice_tiles)))

  defp source_chart(by_role) do
    %{
      labels: Enum.map(by_role, &role_title(&1.role)),
      values: Enum.map(by_role, & &1.total)
    }
  end

  # The ring's centre sums the same rows the ring draws, so the total can never
  # disagree with the slices around it.
  defp source_total(by_role), do: by_role |> Enum.map(& &1.total) |> Enum.sum()

  # ── Render ──────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div id="earnings-page" class="max-w-[1600px] mx-auto space-y-6 px-4 py-8 sm:px-6">
      <.admin_page_header
        title="Every cedi, traced to its source"
        subtitle="Your own sales, resold stock, dropship margin, credit repayments."
        icon="hero-banknotes"
      />

      <.async_result :let={earnings} assign={@earnings}>
        <:loading>
          <div id="earnings-loading" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div id="earnings-tile-total">
              <.money_tile
                label="Total earned"
                icon="hero-banknotes"
                icon_class="text-sky-600"
                tone={:accent}
                state={:loading}
              />
            </div>
            <div id="earnings-tile-month">
              <.money_tile
                label="This month"
                icon="hero-calendar"
                icon_class="text-blue-600"
                tone={:info}
                state={:loading}
              />
            </div>
            <div id="earnings-tile-payable">
              <.money_tile
                label="Payable now"
                icon="hero-clock"
                icon_class="text-emerald-600"
                tone={:success}
                state={:loading}
              />
            </div>
            <div id="earnings-tile-paid-out">
              <.money_tile
                label="Paid out"
                icon="hero-check-circle"
                icon_class="text-slate-600"
                tone={:cyan}
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
                  tone={:accent}
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-month">
                <.money_tile
                  label="This month"
                  icon="hero-calendar"
                  icon_class="text-blue-600"
                  tone={:info}
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-payable">
                <.money_tile
                  label="Payable now"
                  icon="hero-clock"
                  icon_class="text-emerald-600"
                  tone={:success}
                  state={:failed}
                />
              </div>
              <div id="earnings-tile-paid-out">
                <.money_tile
                  label="Paid out"
                  icon="hero-check-circle"
                  icon_class="text-slate-600"
                  tone={:cyan}
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
              tone={:accent}
              footnote="Everything you have earned"
            />
          </div>
          <div id="earnings-tile-month">
            <.money_tile
              label="This month"
              value={Currency.format_price(earnings.this_month, @currency)}
              icon="hero-calendar"
              icon_class="text-blue-600"
              tone={:info}
              footnote="Since the month started"
            />
          </div>
          <div id="earnings-tile-payable">
            <.money_tile
              label="Payable now"
              value={Currency.format_price(earnings.payable_now, @currency)}
              icon="hero-clock"
              icon_class="text-emerald-600"
              tone={:success}
              footnote="Ready to be paid out"
            />
          </div>
          <div id="earnings-tile-paid-out">
            <.money_tile
              label="Paid out"
              value={Currency.format_price(earnings.paid_out, @currency)}
              icon="hero-check-circle"
              icon_class="text-slate-600"
              tone={:cyan}
              footnote="Already sent to you"
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

        <%!-- The ring answers "where did my money come from" before a word is
              read; each source card is painted in its own slice colour so the
              two halves are one picture. --%>
        <div
          :if={earnings.by_role != []}
          class="grid grid-cols-1 gap-4 lg:grid-cols-3 items-start"
        >
          <.admin_card padding={:none} class="p-5">
            <div class="mb-4 flex items-center gap-2">
              <.icon name="hero-chart-pie" class="size-5 text-primary" />
              <h2 class="text-base font-bold text-slate-800">Where it came from</h2>
            </div>
            <div class="relative h-56">
              <canvas
                id="earnings-source-chart"
                phx-hook="ChartHook"
                phx-update="ignore"
                data-chart-type="provider-donut"
                data-chart-data={Jason.encode!(source_chart(earnings.by_role))}
                class="h-full w-full"
              />
              <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                <p class="text-2xl font-bold tabular-nums text-slate-900">
                  {Currency.format_price(source_total(earnings.by_role), @currency)}
                </p>
                <p class="mt-1 text-xs font-semibold uppercase tracking-wider text-slate-400">
                  Total
                </p>
              </div>
            </div>
          </.admin_card>

          <%!-- auto-fit, not a fixed 2-up: most merchants have exactly one
                source ("Your sales"), and a fixed two-column grid left that
                lone card as a short box beside a tall ring with a third of the
                row empty. auto-fit lets one card take the full span and two sit
                side by side. --%>
          <div
            id="earnings-by-source"
            class="grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] auto-rows-fr gap-4 h-full lg:col-span-2"
          >
            <.admin_card
              :for={{group, index} <- Enum.with_index(earnings.by_role)}
              id={"earnings-source-#{group.role}"}
              padding={:none}
              class="p-5"
            >
              <div class="flex items-start gap-4">
                <div class={[
                  "flex h-14 w-14 shrink-0 items-center justify-center rounded-control text-white",
                  slice_tile(index)
                ]}>
                  <.icon name={role_icon(group.role)} class="size-7" />
                </div>
                <div class="min-w-0 flex-1">
                  <h3 class="text-sm font-semibold text-slate-700">{role_title(group.role)}</h3>
                  <p class="mt-1 text-xl font-bold tabular-nums text-slate-900">
                    {Currency.format_price(group.total, @currency)}
                  </p>
                </div>
              </div>
              <div :if={group.sources != []} class="mt-3 space-y-1 border-t border-slate-100 pt-3">
                <div
                  :for={source <- group.sources}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-slate-600">{source.source_name}</span>
                  <span class="font-medium tabular-nums text-slate-800">
                    {Currency.format_price(source.total, @currency)}
                  </span>
                </div>
              </div>
            </.admin_card>
          </div>
        </div>

        <div :if={earnings.feed != []} id="earnings-feed">
          <div class="mb-3 flex items-center gap-2">
            <.icon name="hero-clock" class="size-5 text-primary" />
            <h2 class="text-base font-bold text-slate-800">Recent accruals</h2>
          </div>
          <div class="overflow-x-auto rounded-card border border-border bg-surface shadow-sm">
            <table class="min-w-full divide-y divide-slate-100">
              <thead>
                <tr class="text-left text-xs font-medium uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-3">Date</th>
                  <th class="px-4 py-3">Source</th>
                  <th class="px-4 py-3">Net</th>
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
  attr :tone, :atom, default: :neutral
  attr :footnote, :string, default: nil
  attr :state, :atom, default: :ok, values: [:ok, :loading, :failed]

  defp money_tile(%{state: :loading} = assigns) do
    ~H"""
    <.stat_card label={@label} value="" tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
      <:delta>
        <div class="mt-2 h-7 w-24 animate-pulse rounded bg-slate-200" aria-hidden="true"></div>
        <span class="sr-only">Loading {@label}</span>
      </:delta>
    </.stat_card>
    """
  end

  defp money_tile(%{state: :failed} = assigns) do
    ~H"""
    <.stat_card label={@label} value="—" tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
    </.stat_card>
    """
  end

  defp money_tile(assigns) do
    ~H"""
    <.stat_card label={@label} value={@value} tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
      <:delta :if={@footnote}>
        <p class="text-sm text-slate-500">{@footnote}</p>
      </:delta>
    </.stat_card>
    """
  end
end
