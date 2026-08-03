defmodule EmakolaWeb.Platform.FinanceLiveTest do
  @moduledoc """
  Platform finance oversight page (/platform/finance): revenue stat strip
  (fees collected, GMV, take rate, outstanding payouts) + per-store breakdown,
  permission gating, disconnected shell, and the empty state.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments.Workers.PayoutWorker

  defp success_payment!(store, attrs) do
    store
    |> Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp momo_account!(store) do
    {:ok, _} =
      Emakola.Stores.create_payout_account(
        %{
          store_id: store.id,
          payout_destination: %{
            "method" => "mobile_money",
            "provider" => "mtn",
            "number" => "0244123456",
            "account_name" => "Kwame Owusu"
          }
        },
        authorize?: false
      )
  end

  defp platform_fee_split!(payment, amount) do
    Emakola.Payments.create_payment_split!(
      %{store_id: payment.store_id, payment_id: payment.id, role: :platform, amount: amount},
      authorize?: false
    )
  end

  test "staff without :manage_billing is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/finance")
  end

  describe "disconnected mount" do
    test "renders a loading shell (skeleton tiles, not bare text), not live data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!(%{name: "Disconnected Co"})
      success_payment!(store, %{amount: 50_000})

      html = get(conn, "/platform/finance") |> html_response(200)

      assert html =~ "Loading"
      assert html =~ "animate-pulse"
      refute html =~ "Disconnected Co"
    end
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "renders via the shared page_header component", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/finance")
      assert has_element?(view, "h1", "Finance")
    end

    test "shows the empty state when there is no finance activity", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/finance")
      assert html =~ "No finance activity"
    end

    test "renders the revenue stat strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/finance")
      assert html =~ "Platform fees collected"
      assert html =~ "Outstanding"
      assert html =~ "GH₵"
    end

    test "renders a per-store row with fees, outstanding and payout readiness", %{conn: conn} do
      owed_store = Factory.create_store!(%{name: "Owed Kingdom"})
      success_payment!(owed_store, %{amount: 80_000})

      fee_store = Factory.create_store!(%{name: "Fee Palace"})
      momo_account!(fee_store)
      payment = success_payment!(fee_store, %{amount: 10_000, split_mode: :dropship_split})

      # Settled, not pending: only confirmed fees count as revenue now, and a
      # store whose only activity is an unconfirmed fee has no finance row.
      payment
      |> platform_fee_split!(200)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/platform/finance")

      assert html =~ "Owed Kingdom"
      assert html =~ "Fee Palace"
      # owed store has no payout set up; fee store is ready
      assert html =~ "No payout set up"

      # payouts_ready? = MoMo-destination-present (P2 semantic — transfers are what payouts actually need)
      assert html =~ "Ready"
    end

    test "shows a Pay out button for a store with an outstanding balance", %{conn: conn} do
      store = Factory.create_store!(%{name: "Owed Co"})
      success_payment!(store, %{amount: 80_000})

      {:ok, _view, html} = live(conn, ~p"/platform/finance")
      assert html =~ "Pay out"
    end

    test "approving a payout enqueues the worker, audits, and clears the backlog", %{
      conn: conn,
      user: user
    } do
      store = Factory.create_store!(%{name: "Owed Co"})
      momo_account!(store)
      success_payment!(store, %{amount: 80_000})

      {:ok, view, _html} = live(conn, ~p"/platform/finance")

      html =
        view
        |> element("button[phx-click='approve_payout'][phx-value-store_id='#{store.id}']")
        |> render_click()

      assert html =~ "queued" or html =~ "Payout"
      assert_enqueued(worker: PayoutWorker)

      # A pending payout was created and the backlog stamped clear.
      assert [payout] = Emakola.Payments.list_payouts_by_store!(store.id, authorize?: false)
      assert payout.amount == 80_000
      assert payout.status == :pending

      # Audit entry recorded against the approving staffer.
      page = Emakola.Accounts.list_platform_audit_logs!(authorize?: false, page: [limit: 200])
      assert Enum.any?(page.results, &(&1.action == :payout_approved and &1.actor_id == user.id))
    end

    test "approving a store with no MoMo details flashes an error and creates no payout", %{
      conn: conn
    } do
      store = Factory.create_store!(%{name: "No MoMo Co"})
      success_payment!(store, %{amount: 80_000})

      {:ok, view, _html} = live(conn, ~p"/platform/finance")

      # The Pay-out button is disabled (not hidden) for a store with no payout
      # destination — see the disabled-button test below — so a real click
      # can't reach the server. Dispatch the event directly to prove the
      # server-side rejection path (defense in depth) is still intact.
      html = render_click(view, "approve_payout", %{"store_id" => store.id})

      assert html =~ "mobile money" or html =~ "payout details"
      assert Emakola.Payments.list_payouts_by_store!(store.id, authorize?: false) == []
    end

    test "renders recent payouts with their status", %{conn: conn} do
      store = Factory.create_store!(%{name: "Payout Co"})

      Emakola.Payments.create_payout!(
        %{store_id: store.id, amount: 80_000, transfer_reference: "po_render"},
        authorize?: false
      )

      {:ok, _view, html} = live(conn, ~p"/platform/finance")

      assert html =~ "Recent payouts"
      assert html =~ "Payout Co"
      assert html =~ "Pending"
    end

    test "retrying a failed payout prepares a FRESH payout (not the dead one) and audits",
         %{conn: conn, user: user} do
      store = Factory.create_store!(%{name: "Failed Co"})

      # A MoMo destination + outstanding balance — the state a failed transfer
      # leaves behind once its balance is released back to outstanding.
      {:ok, _} =
        Emakola.Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{
              "method" => "mobile_money",
              "provider" => "mtn",
              "number" => "0244123456",
              "account_name" => "Kwame"
            }
          },
          authorize?: false
        )

      store
      |> Factory.create_payment!(%{amount: 80_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 80_000, transfer_reference: "po_retry"},
          authorize?: false
        )

      {:ok, failed} =
        Emakola.Payments.mark_payout_failed(payout, %{failure_reason: "timeout"},
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/finance")

      view
      |> element("button[phx-value-payout_id='#{failed.id}']")
      |> render_click()

      # Retry prepares a fresh payout (new reference) and enqueues THAT — never the
      # dead :failed payout (Paystack rejects a reused reference).
      assert_enqueued(worker: PayoutWorker)
      refute_enqueued(worker: PayoutWorker, args: %{"payout_id" => failed.id})

      page = Emakola.Accounts.list_platform_audit_logs!(authorize?: false, page: [limit: 200])
      assert Enum.any?(page.results, &(&1.action == :payout_retried and &1.actor_id == user.id))
    end

    test "shows no retry button for a non-failed payout", %{conn: conn} do
      store = Factory.create_store!(%{name: "Pending Co"})

      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 80_000, transfer_reference: "po_pending"},
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/finance")
      refute has_element?(view, "button[phx-value-payout_id='#{payout.id}']")
    end

    test "Pay-out button is disabled with a reason when the store has no payout destination", %{
      conn: conn
    } do
      store = Factory.create_store!(%{name: "No Destination Co"})
      success_payment!(store, %{amount: 80_000})

      {:ok, view, _html} = live(conn, ~p"/platform/finance")

      assert has_element?(
               view,
               "button[disabled][phx-click='approve_payout'][phx-value-store_id='#{store.id}']"
             )

      html = render(view)
      assert html =~ "Add a mobile money payout destination"
    end
  end
end
