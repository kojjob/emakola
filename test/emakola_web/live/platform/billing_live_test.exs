defmodule EmakolaWeb.Platform.BillingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "permission gating" do
    test "owner can mount /platform/billing", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff with :manage_billing can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_billing])
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff without :manage_billing is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/billing")

      assert flash["error"] =~ "permission"
    end
  end

  describe "disconnected mount" do
    test "renders a loading shell without hitting the DB", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      Factory.create_plan!(%{name: "Visible Plan"})

      conn = get(conn, ~p"/platform/billing")
      html = html_response(conn, 200)

      assert html =~ "Loading"
      refute html =~ "Visible Plan"
    end
  end

  describe "content" do
    setup %{conn: conn} do
      plan = Factory.create_plan!(%{name: "Growth Plan", price_cents: 2900, interval: :monthly})
      org = Factory.create_organisation!(%{name: "Acme Org"})
      Factory.create_subscription!(org, plan, status: :active)
      Factory.create_invoice!(org, invoice_number: "INV-SHOWN", amount_cents: 2900)
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, conn: conn}
    end

    test "renders plans, subscriptions, and invoices", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Growth Plan"
      assert html =~ "Acme Org"
      assert html =~ "INV-SHOWN"
    end

    test "stat strip shows labels and a non-zero MRR", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "MRR"
      assert html =~ "Active subscriptions"
      assert html =~ "$29.00"
    end
  end

  describe "empty state" do
    test "renders empty states when there is no billing data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "No plans configured"
      assert html =~ "No subscriptions yet"
    end
  end
end
