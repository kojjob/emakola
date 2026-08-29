defmodule EmakolaWeb.Admin.EarningsLiveTest do
  @moduledoc """
  The flagship money-surfaces page (PR-2, Task 2): where a merchant sees
  where every cedi of earnings came from. Loads Task 1's
  `list_earnings_splits/2` in one `assign_async` and derives the hero
  tiles (total earned / this month / payable now / paid out), the
  by-source breakdown, and the recent-accruals feed from those same rows.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments.PaymentSplit
  alias EmakolaWeb.Helpers.Currency

  setup %{conn: conn} do
    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  # (a) — skeleton while loading, never a zero
  describe "earnings picture — loading" do
    test "while the earnings async is pending, tiles show a skeleton and no zero", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/earnings")

      assert html =~ "earnings-loading"
      refute html =~ "0.00"
      refute html =~ Currency.currency_symbol("GHS")
    end
  end

  # (b) — a failed async renders a dash, never a zero
  describe "earnings picture — failure" do
    # Arranging a genuine `assign_async` failure through the full pipeline
    # isn't cheaply reachable — `list_earnings_splits` tolerates a
    # nonexistent store_id by returning an empty list rather than raising,
    # and the project has no stub/mock seam for plain Ash domain calls. Per
    # payout_live's precedent, render the failed-clause markup directly
    # with a hand-built `AsyncResult.failed/2` assign.
    test "a failed earnings load renders a dash treatment, never a zero" do
      assigns = %{
        currency: "GHS",
        earnings:
          Phoenix.LiveView.AsyncResult.failed(Phoenix.LiveView.AsyncResult.loading(), :boom)
      }

      html =
        assigns
        |> EmakolaWeb.Admin.EarningsLive.render()
        |> rendered_to_string()

      assert html =~ "Couldn't load"
      assert html =~ "—"
      refute html =~ "0.00"
    end
  end

  # (c) — hero strip arithmetic from mixed fixtures
  describe "earnings picture — hero tiles" do
    test "total earned / this month / payable now / paid out match the Task 1 contract", %{
      conn: conn,
      store: store
    } do
      other_store = Factory.create_store!()

      # This month, unclaimed: merchant own-sale + wholesaler resale (from
      # another tenant) + dropshipper margin.
      merchant_payment = Factory.create_payment!(store, %{amount: 10_000})
      settled!(store, merchant_payment, %{role: :merchant, amount: 10_000})

      resale_payment = Factory.create_payment!(other_store, %{amount: 20_000})

      settled!(other_store, resale_payment, %{
        role: :wholesaler,
        recipient_store_id: store.id,
        amount: 20_000
      })

      dropship_payment = Factory.create_payment!(store, %{amount: 5_000})
      settled!(store, dropship_payment, %{role: :dropshipper, amount: 5_000})

      # Claimed + paid out — excluded from "payable now", included in "paid out".
      claimed_payment = Factory.create_payment!(store, %{amount: 8_000})
      claimed!(store, claimed_payment, %{role: :merchant, amount: 8_000})

      # Reversed — excluded from every tile (frozen nets to 0).
      reversed_payment = Factory.create_payment!(store, %{amount: 3_000})
      reversed!(store, reversed_payment, %{role: :merchant, amount: 3_000})

      # Settled last month, still unclaimed — counts toward total earned and
      # payable now, but NOT this month.
      old_payment = Factory.create_payment!(store, %{amount: 50_000})
      last_month = DateTime.add(DateTime.utc_now(), -32, :day)
      settled!(store, old_payment, %{role: :merchant, amount: 50_000}, last_month)

      # Settled via the gateway rail (the default for non-platform roles —
      # see OrderSettlement.default_settlement_method/1): money already left
      # the platform at charge time, so `paid_out_at` can never be set for
      # it. Counts toward total earned / this month but must NEVER appear as
      # "payable now" — that money isn't sitting in Makola's ledger.
      gateway_payment = Factory.create_payment!(store, %{amount: 6_000})

      settled!(store, gateway_payment, %{
        role: :merchant,
        amount: 6_000,
        settlement_method: :gateway_share
      })

      # Partially reversed via `record_reversal` — reversed 6,000 of a
      # 20,000 settled (internal_hold) split. Hand-check:
      #   frozen_paid_amount = amount - (reversed - recovered - reserved)
      #                      = 20,000 - (6,000 - 0 - 0) = 14,000
      # reversed_amount (6,000) < amount (20,000), so status stays
      # :partially_reversed rather than flipping to :reversed — it still
      # counts toward total earned, this month, and payable now (unclaimed).
      partial_payment = Factory.create_payment!(store, %{amount: 20_000})
      partially_reversed!(store, partial_payment, %{role: :merchant, amount: 20_000}, 6_000)

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      currency = store.currency || "GHS"

      # total earned = 10,000 (merchant) + 20,000 (resale) + 5,000 (dropship)
      #              + 8,000 (claimed) + 50,000 (old, unclaimed)
      #              + 6,000 (gateway) + 14,000 (partial) = 113,000
      assert view |> element("#earnings-tile-total") |> render() =~
               Currency.format_price(113_000, currency)

      # this month = total minus the 50,000 backdated-last-month row = 63,000
      assert view |> element("#earnings-tile-month") |> render() =~
               Currency.format_price(63_000, currency)

      # payable now = internal_hold, unclaimed, settled/partially_reversed:
      # 10,000 + 20,000 + 5,000 + 50,000 (old) + 14,000 (partial) = 99,000
      # (claimed excluded; gateway_share excluded — see internally_payable?/1)
      assert view |> element("#earnings-tile-payable") |> render() =~
               Currency.format_price(99_000, currency)

      assert view |> element("#earnings-tile-paid-out") |> render() =~
               Currency.format_price(8_000, currency)
    end

    # payable_now escaping the 100-row history cap (fix wave — see the
    # module doc): a genuine >cap proof needs 101 fixtures, too heavy for
    # this suite. This is the cheap version instead — an old, unclaimed
    # split (the kind a 100-row cap would evict from `list_earnings_splits`
    # in a busy store) still counts toward payable now, because
    # `payable_now` sums `list_payable_internal_splits` (unbounded)
    # directly rather than filtering the capped history read. The actual
    # >100-row guarantee rests on that being a SEPARATE, unbounded read (see
    # the module doc) rather than on this test proving the cap boundary.
    test "an old unclaimed split still counts toward payable now (the read it uses is unbounded)",
         %{conn: conn, store: store} do
      recent_payment = Factory.create_payment!(store, %{amount: 6_000})
      settled!(store, recent_payment, %{role: :merchant, amount: 6_000})

      old_payment = Factory.create_payment!(store, %{amount: 9_000})
      long_ago = DateTime.add(DateTime.utc_now(), -400, :day)
      settled!(store, old_payment, %{role: :merchant, amount: 9_000}, long_ago)

      claimed_payment = Factory.create_payment!(store, %{amount: 4_000})
      claimed!(store, claimed_payment, %{role: :merchant, amount: 4_000})

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      # 6,000 (recent) + 9,000 (old, still unclaimed) = 15,000; the claimed
      # 4,000 stays excluded.
      assert view |> element("#earnings-tile-payable") |> render() =~
               Currency.format_price(15_000, store.currency || "GHS")
    end
  end

  # (c2) — the page reads like the rest of the admin
  describe "earnings picture — visual treatment" do
    test "the page uses the admin's full-width container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/earnings")

      # Every other admin page is max-w-[1600px]; earnings sat at max-w-6xl and
      # read as a different product.
      assert html =~ "max-w-[1600px]"
    end

    test "each money tile carries its own hue, so the row is readable without reading",
         %{conn: conn, store: store} do
      payment = Factory.create_payment!(store, %{amount: 10_000})
      settled!(store, payment, %{role: :merchant, amount: 10_000})

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      assert view |> element("#earnings-tile-total") |> render() =~ "bg-violet-600"
      assert view |> element("#earnings-tile-payable") |> render() =~ "bg-emerald-500"
      assert view |> element("#earnings-tile-month") |> render() =~ "bg-info"
    end

    test "where the money came from is drawn as a ring, not only listed", %{
      conn: conn,
      store: store
    } do
      payment = Factory.create_payment!(store, %{amount: 10_000})
      settled!(store, payment, %{role: :merchant, amount: 10_000})

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      assert has_element?(view, "#earnings-source-chart[data-chart-type='provider-donut']")
    end
  end

  # (d) — the resale card names the source store
  describe "earnings picture — by-source cards" do
    test "the resale card names the source store", %{conn: conn, store: store} do
      wholesaler_store = Factory.create_store!(%{name: "Kwame Wholesale"})
      payment = Factory.create_payment!(wholesaler_store, %{amount: 15_000})

      settled!(wholesaler_store, payment, %{
        role: :wholesaler,
        recipient_store_id: store.id,
        amount: 15_000
      })

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      resale_html = view |> element("#earnings-source-wholesaler") |> render()

      assert resale_html =~ "Kwame Wholesale"
      assert resale_html =~ Currency.format_price(15_000, store.currency || "GHS")
    end
  end

  # (e) — recent accruals feed, including order-less (susu) splits
  describe "earnings picture — recent accruals feed" do
    test "renders order-less splits gracefully alongside a normal one", %{
      conn: conn,
      store: store
    } do
      # Susu contributions have no order — a plain payment (no order_id).
      susu_payment = Factory.create_payment!(store, %{amount: 7_000})
      settled!(store, susu_payment, %{role: :merchant, amount: 7_000})

      order_payment = Factory.create_payment!(store, %{amount: 4_000})
      settled!(store, order_payment, %{role: :dropshipper, amount: 4_000})

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      feed_html = view |> element("#earnings-feed") |> render()

      assert feed_html =~ "Your sale"
      assert feed_html =~ Currency.format_price(7_000, store.currency || "GHS")
      assert feed_html =~ "Dropship margin"
      assert feed_html =~ Currency.format_price(4_000, store.currency || "GHS")
    end
  end

  # (f) — empty state for a new store
  describe "earnings picture — empty state" do
    test "a store with no earnings sees a rich empty state pointing at listings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      assert view |> element("#earnings-empty") |> render() =~ "No earnings yet"
      assert view |> element("#earnings-empty") |> render() =~ "View your listings"
    end
  end

  # An all-reversed store must not show the empty state AND a feed row at
  # once: the empty state used to gate on `by_role` (derived from ACTIVE —
  # i.e. non-reversed — splits), while the feed derives from raw splits, so
  # a store whose only sale was fully refunded showed "No earnings yet" and
  # a feed row simultaneously. The empty state now gates on the raw feed.
  describe "earnings picture — all-reversed store" do
    test "shows the reversed row in the feed, not the empty state", %{
      conn: conn,
      store: store
    } do
      payment = Factory.create_payment!(store, %{amount: 9_000})
      reversed!(store, payment, %{role: :merchant, amount: 9_000})

      {:ok, view, _html} = live(conn, ~p"/admin/earnings")
      render_async(view)

      refute has_element?(view, "#earnings-empty")

      feed_html = view |> element("#earnings-feed") |> render()
      assert feed_html =~ "Your sale"
      # frozen_paid_amount = amount - reversed_amount = 9,000 - 9,000 = 0 —
      # the reversed row's honest net.
      assert feed_html =~ Currency.format_price(0, store.currency || "GHS")
    end
  end

  # (g) — route + nav
  describe "earnings picture — route and nav" do
    test "an authenticated merchant reaches /admin/earnings and the nav renders the entry", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/earnings")

      assert html =~ "Every cedi, traced to its source"
      assert html =~ ~s(<a href="/admin/earnings" title="Earnings")
    end
  end

  # ── Fixtures ─────────────────────────────────────────────────────

  defp split!(store, payment, attrs, inserted_at) do
    default = %{
      store_id: store.id,
      payment_id: payment.id,
      role: :merchant,
      recipient_store_id: store.id,
      amount: 10_000,
      settlement_method: :internal_hold
    }

    changeset =
      default
      |> Map.merge(Map.new(attrs))
      |> then(&Ash.Changeset.for_create(PaymentSplit, :create, &1))

    changeset =
      if inserted_at,
        do: Ash.Changeset.force_change_attribute(changeset, :inserted_at, inserted_at),
        else: changeset

    Ash.create!(changeset, authorize?: false)
  end

  defp settled!(store, payment, attrs, inserted_at \\ nil) do
    store
    |> split!(payment, attrs, inserted_at)
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reversed!(store, payment, attrs) do
    store
    |> settled!(payment, attrs)
    |> Ash.Changeset.for_update(:mark_reversed, %{})
    |> Ash.update!(authorize?: false)
  end

  defp claimed!(store, payment, attrs) do
    store
    |> settled!(payment, attrs)
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)
  end

  defp partially_reversed!(store, payment, attrs, reversed_amount) do
    store
    |> settled!(payment, attrs)
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
    |> Ash.update!(authorize?: false)
  end
end
