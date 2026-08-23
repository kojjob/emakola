defmodule EmakolaWeb.Admin.RevenueLiveTest do
  @moduledoc """
  LiveView tests for the admin revenue analytics page.

  Every figure on this page must come from this store's own rows. The page
  previously shipped `assign_placeholder_data/1` — invented KPIs, six invented
  customers, three invented payouts — and this file's assertions were what held
  that fiction in place. The tests below assert the opposite: real sums, real
  rows, store isolation, and no fabricated string anywhere in the markup.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments.PaymentSplit

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store, merchant: merchant}
  end

  describe "money figures" do
    test "gross revenue sums this store's successful payments", %{conn: conn, store: store} do
      succeed!(store, 40_000)
      succeed!(store, 90_000)
      # Pending money has not arrived; it must not be counted as revenue.
      Factory.create_payment!(store, %{amount: 55_000})

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert has_element?(view, "#stat-revenue-gross", "1,300.00")
      refute has_element?(view, "#stat-revenue-gross", "1,850.00")
    end

    test "another store's money never appears", %{conn: conn, store: store} do
      succeed!(store, 40_000)

      other_store = Factory.create_store!()
      succeed!(other_store, 900_000)

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert has_element?(view, "#stat-revenue-gross", "400.00")
      refute render(view) =~ "9,000.00"
    end

    test "platform fees come from the platform splits, net of reversals", %{
      conn: conn,
      store: store
    } do
      payment = succeed!(store, 100_000)
      # 2% of 100_000 = 2_000, of which 500 was later reversed with the refund.
      platform_split!(store, payment, amount: 2_000, reversed_amount: 500)

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert has_element?(view, "#stat-revenue-fees", "15.00")
      refute has_element?(view, "#stat-revenue-fees", "20.00")
    end

    test "net revenue is gross minus the fees actually charged", %{conn: conn, store: store} do
      payment = succeed!(store, 100_000)
      platform_split!(store, payment, amount: 2_000)

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert has_element?(view, "#stat-revenue-gross", "1,000.00")
      assert has_element?(view, "#stat-revenue-fees", "20.00")
      assert has_element?(view, "#stat-revenue-net", "980.00")
    end

    test "a store with no platform splits shows no fee, and net equals gross", %{
      conn: conn,
      store: store
    } do
      succeed!(store, 70_000)

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert has_element?(view, "#stat-revenue-fees", "0.00")
      assert has_element?(view, "#stat-revenue-net", "700.00")
    end

    # The same number is on /admin/payouts and /admin/earnings. If the three
    # pages can disagree about what is owed, a merchant cannot trust any of them.
    test "pending payouts matches what the payouts page calls outstanding", %{
      conn: conn,
      store: store
    } do
      succeed!(store, 40_000)
      succeed!(store, 25_000)

      outstanding =
        store.id
        |> Emakola.Payments.PayoutService.outstanding_payments()
        |> Enum.map(&(&1.payable_amount || &1.amount))
        |> Enum.sum()

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      assert outstanding == 65_000
      assert has_element?(view, "#stat-revenue-pending", "650.00")
    end
  end

  describe "period" do
    test "the period pill narrows what is counted", %{conn: conn, store: store} do
      succeed!(store, 40_000)
      old = succeed!(store, 90_000)
      backdated = backdate!(old, -45)

      # Prove the backdate actually persisted. A silent no-op here would make
      # the range assertions below pass for the wrong reason.
      assert DateTime.diff(DateTime.utc_now(), backdated.inserted_at, :day) >= 44

      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      # Default period is this month: the 45-day-old payment is outside it.
      assert has_element?(view, "#stat-revenue-gross", "400.00")
      refute has_element?(view, "#stat-revenue-gross", "1,300.00")

      html =
        view
        |> element("button[phx-click='change_period'][phx-value-period='year']")
        |> render_click()

      assert html =~ "1,300.00"
    end
  end

  describe "rows" do
    test "the transactions table lists this store's real payments", %{conn: conn, store: store} do
      order = Factory.create_order!(store, total: 40_000)
      payment = Factory.create_payment!(store, %{amount: 40_000, order_id: order.id})
      mark_success!(payment)

      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ order.order_number
      assert html =~ "customer@example.com"
    end

    test "payout history lists this store's real payouts", %{conn: conn, store: store} do
      {:ok, payout} =
        Emakola.Payments.create_payout(
          %{
            store_id: store.id,
            amount: 42_000,
            currency: "GHS",
            transfer_reference: "PO-#{Ecto.UUID.generate()}",
            basis: :payments
          },
          authorize?: false
        )

      {:ok, _paid} = Emakola.Payments.mark_payout_paid(payout, %{}, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "420.00"
    end
  end

  describe "status colours" do
    # A merchant scanning the table reads colour before words. Rendering a
    # successful payment in the same grey as a failed one is a money page
    # telling them nothing.
    test "a successful payment does not wear the same badge as a failed one", %{
      conn: conn,
      store: store
    } do
      succeed!(store, 40_000)

      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "bg-success-soft"
    end

    test "a paid payout is marked paid, not left neutral", %{conn: conn, store: store} do
      {:ok, payout} =
        Emakola.Payments.create_payout(
          %{
            store_id: store.id,
            amount: 42_000,
            currency: "GHS",
            transfer_reference: "PO-#{Ecto.UUID.generate()}",
            basis: :payments
          },
          authorize?: false
        )

      {:ok, _paid} = Emakola.Payments.mark_payout_paid(payout, %{}, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "bg-success-soft"
    end
  end

  describe "no invented data" do
    test "an empty store shows zeros, not a fabricated dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      # The placeholder KPI figures.
      refute html =~ "38,470.00"
      refute html =~ "34,623.00"
      refute html =~ "769.40"
      refute html =~ "4,280.00"
    end

    test "no invented customers, categories or payout dates anywhere", %{conn: conn, store: store} do
      succeed!(store, 40_000)

      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      for invented <- [
            "Ama Mensah",
            "Kofi Adjei",
            "Akua Owusu",
            "Yaw Boateng",
            "Efua Darko",
            "Nana Osei",
            "EM-4821",
            "Dresses",
            "22/03/2026",
            "15/03/2026",
            "+233 24 XXX XXXX"
          ] do
        refute html =~ invented, "the page still renders the invented value #{invented}"
      end
    end

    # There is no payment-instrument field on Payment — only `gateway`
    # (:paystack | :hubtel). MoMo/card/COD percentages cannot be derived from
    # anything, so they must not be shown.
    test "no payment-instrument breakdown, which the schema cannot support", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      refute html =~ "Cash on Delivery"
      refute html =~ "Telecel Cash"
    end
  end

  describe "page shell" do
    test "renders revenue page with title and subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Revenue"
      assert html =~ "Track your earnings and payouts"
    end

    test "displays the period toggle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Today"
      assert html =~ "This Week"
      assert html =~ "This Month"
      assert html =~ "This Year"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login", %{} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(build_conn(), ~p"/admin/revenue")
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp succeed!(store, amount) do
    store
    |> Factory.create_payment!(%{amount: amount})
    |> mark_success!()
  end

  defp mark_success!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  # inserted_at is not writable through any action.
  defp backdate!(payment, days) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.Changeset.force_change_attribute(
      :inserted_at,
      DateTime.add(DateTime.utc_now(), days, :day)
    )
    |> Ash.update!(authorize?: false)
  end

  # The platform's cut: role :platform, recipient_store_id nil, tenant is the
  # merchant's store (payment_split.ex:46).
  # A reversal is not writable at create time — `:mark_settled` requires a
  # :pending split and `:record_reversal` is the only action that accepts
  # reversed_amount, so the order is create -> settle -> reverse.
  defp platform_split!(store, payment, attrs) do
    {reversed, attrs} = attrs |> Map.new() |> Map.pop(:reversed_amount)

    split =
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :platform,
        recipient_store_id: nil,
        amount: 2_000,
        settlement_method: :internal_hold
      }
      |> Map.merge(attrs)
      |> then(&Ash.Changeset.for_create(PaymentSplit, :create, &1))
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)

    if reversed do
      split
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed})
      |> Ash.update!(authorize?: false)
    else
      split
    end
  end
end
