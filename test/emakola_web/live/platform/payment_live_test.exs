defmodule EmakolaWeb.Platform.PaymentLiveTest do
  @moduledoc "Tests for /platform/payments — access, disconnected shell, content, and empty states."
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  # ── seed helper ───────────────────────────────────────────────────

  defp pay!(store, gateway, status, attrs \\ %{}) do
    p =
      Factory.create_payment!(
        store,
        Map.merge(%{gateway: gateway, amount: 10_000}, attrs)
      )

    case status do
      :success ->
        p
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :failed ->
        p
        |> Ash.Changeset.for_update(:mark_failed, %{})
        |> Ash.update!(authorize?: false)

      :refunded ->
        succeeded =
          p
          |> Ash.Changeset.for_update(:mark_success, %{})
          |> Ash.update!(authorize?: false)

        succeeded
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: succeeded.amount})
        |> Ash.update!(authorize?: false)

      :pending ->
        p
    end
  end

  # ── access ────────────────────────────────────────────────────────

  describe "access" do
    test "platform owner can mount /platform/payments", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform/payments")
      assert html =~ "Payments"
    end

    test "staff with :manage_billing can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_billing])

      {:ok, _view, html} = live(conn, "/platform/payments")
      assert html =~ "Payments"
    end

    test "staff without :manage_billing is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, "/platform/payments")

      assert flash["error"] =~ "permission"
    end
  end

  # ── disconnected mount ────────────────────────────────────────────

  describe "disconnected mount" do
    test "renders a loading shell, not live data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      unique_email = "disconnected-#{System.unique_integer([:positive])}@example.com"
      store = Factory.create_store!()
      pay!(store, :paystack, :failed, %{customer_email: unique_email})

      # HTTP GET triggers disconnected mount (connected? == false)
      html = get(conn, "/platform/payments") |> html_response(200)

      assert html =~ "Loading"
      refute html =~ unique_email
    end
  end

  # ── content ───────────────────────────────────────────────────────

  describe "content" do
    setup %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store_a = Factory.create_store!()
      store_b = Factory.create_store!()

      # 1 success + 1 failed across two gateways/stores → 50% success rate
      pay!(store_a, :paystack, :success, %{amount: 50_000})
      pay!(store_b, :hubtel, :failed, %{customer_email: "fail@example.com"})
      pay!(store_a, :paystack, :refunded, %{amount: 20_000})

      %{conn: conn, store_a: store_a, store_b: store_b}
    end

    test "shows stat labels", %{conn: conn} do
      {:ok, view, html} = live(conn, "/platform/payments")

      assert html =~ "Total payments"
      assert html =~ "Success rate"
      assert html =~ "GMV"
      assert html =~ "Refunds"
      assert has_element?(view, "#recent-refunds[phx-update='stream']")
      assert has_element?(view, "#recent-refunds > tr[id^='refunds-']")
    end

    test "the hero charts daily GMV and the strip counts failures", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/platform/payments")

      assert has_element?(
               view,
               "canvas#payments-gmv-chart[phx-hook='ChartHook'][data-chart-type='gmv-line']"
             )

      assert has_element?(view, "#payments-failed-count", "1")
    end

    test "shows gateway labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/payments")

      assert html =~ "Paystack"
      assert html =~ "Hubtel"
    end

    test "shows failed payment email and store name", %{conn: conn, store_b: store_b} do
      {:ok, view, html} = live(conn, "/platform/payments")

      assert has_element?(view, "#failed-payments[phx-update='stream']")
      assert has_element?(view, "#failed-payments > tr[id^='failed-']")
      assert html =~ "fail@example.com"
      assert html =~ store_b.name
    end

    test "shows formatted GHS amount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/payments")

      assert html =~ "GHS"
    end

    test "shows 50% success rate when 1 success and 1 failed", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/payments")

      assert html =~ "50%"
    end
  end

  # ── empty state ───────────────────────────────────────────────────

  describe "empty state" do
    test "shows no-failed-payments copy when all payments are successful", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!()
      pay!(store, :paystack, :success)

      {:ok, view, _html} = live(conn, "/platform/payments")

      assert has_element?(view, "#failed-payments[phx-update='stream']")
      assert has_element?(view, "#failed-payments-empty")

      refute has_element?(
               view,
               "#failed-payments > tr[id^='failed-']:not(#failed-payments-empty)"
             )
    end
  end
end
