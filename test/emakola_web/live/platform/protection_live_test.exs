defmodule EmakolaWeb.Platform.ProtectionLiveTest do
  @moduledoc """
  Platform staff buyer-protection queue (`/platform/protection`, gated
  :manage_billing): frozen holds (open complaint) + stale holds (:held,
  never started the auto-release timer, 30+ days old), with two actions —
  force-release (a frozen hold additionally gets resolution:
  :released_by_staff) and staff refund (initiates through the same
  RefundService the merchant returns flow uses, with :refunded_by_staff —
  does NOT close the hold synchronously, only the refund webhook does).
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  require Ash.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Factory
  alias Emakola.Payments

  defp audit(event) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(action == ^event)
    |> Ash.read!(authorize?: false, page: [limit: 200])
    |> Map.get(:results)
  end

  defp protected_hold!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)
    amount = Map.get(attrs, :amount, 25_000)
    order_attrs = Map.get(attrs, :order_attrs, %{})

    order =
      Factory.create_order!(
        store,
        Map.merge(%{total: amount, shipping_address: %{"phone" => "0244123456"}}, order_attrs)
      )

    payment =
      store
      |> Factory.create_payment!(%{
        order_id: order.id,
        amount: amount,
        payout_held: true,
        payout_hold_reason: "buyer_protection"
      })
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    :ok = Emakola.Payments.ProtectionHolds.ensure_hold(payment)

    {:ok, hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    hold
  end

  defp force_age!(hold_id, days: days) do
    past = DateTime.add(DateTime.utc_now(), -days, :day)

    Emakola.Repo.update_all(
      from(h in "protection_holds", where: h.id == type(^hold_id, Ecto.UUID)),
      set: [inserted_at: past]
    )
  end

  setup %{conn: conn} do
    {conn, user, _s} = setup_platform_staff(conn, permissions: [:manage_billing])
    store = Factory.create_store!(%{name: "Kente Co"})
    %{conn: conn, user: user, store: store}
  end

  test "staff without :manage_billing is redirected to /platform", %{conn: conn} do
    {conn, _u, _s} = setup_platform_staff(conn, permissions: [:view_audit_log])
    assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/protection")
  end

  test "lists frozen holds with complaint details, order/store context, and phone last-4 only",
       %{conn: conn, store: store} do
    hold = protected_hold!(store)

    {:ok, _frozen} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :not_received, complaint_text: "Never arrived"},
        authorize?: false
      )

    {:ok, _view, html} = live(conn, ~p"/platform/protection")

    assert html =~ "Kente Co"
    assert html =~ "Not received"
    assert html =~ "Never arrived"
    assert html =~ "3456"
    refute html =~ "0244123456"
  end

  test "lists stale holds (:held, no release timer, 30+ days old)", %{conn: conn, store: store} do
    hold = protected_hold!(store)
    force_age!(hold.id, days: 31)

    {:ok, _view, html} = live(conn, ~p"/platform/protection")

    assert html =~ "Kente Co"
  end

  test "does not list a fresh (not yet stale) held hold", %{conn: conn, store: store} do
    _hold = protected_hold!(store, order_attrs: %{shipping_address: %{"phone" => "0201112222"}})

    {:ok, _view, html} = live(conn, ~p"/platform/protection")

    refute html =~ "2222"
  end

  test "force-release releases a frozen hold, stamps resolution: :released_by_staff, and audits",
       %{conn: conn, user: user, store: store} do
    hold = protected_hold!(store)

    {:ok, _frozen} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :other, complaint_text: "Item never showed up"},
        authorize?: false
      )

    {:ok, view, _html} = live(conn, ~p"/platform/protection")

    view
    |> element("button[phx-click='force_release'][phx-value-id='#{hold.id}']")
    |> render_click()

    {:ok, released} =
      Payments.get_protection_hold_by_payment(hold.payment_id,
        tenant: store.id,
        authorize?: false
      )

    assert released.status == :released
    assert released.release_reason == :staff
    assert released.resolution == :released_by_staff

    assert [entry] = audit(:protection_force_released)
    assert entry.actor_id == user.id
    assert entry.metadata["hold_id"] == hold.id
  end

  test "refund buyer initiates a refund via RefundService (:refunded_by_staff) without closing the hold, and audits",
       %{conn: conn, user: user, store: store} do
    hold = protected_hold!(store)

    {:ok, _frozen} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :not_as_described, complaint_text: "Wrong item"},
        authorize?: false
      )

    {:ok, view, _html} = live(conn, ~p"/platform/protection")

    html =
      view
      |> element("button[phx-click='refund_buyer'][phx-value-id='#{hold.id}']")
      |> render_click()

    assert html =~ "initiated"

    # The hold does NOT close synchronously — only the refund webhook does,
    # once `refund.processed` confirms the money actually moved.
    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(hold.payment_id,
        tenant: store.id,
        authorize?: false
      )

    assert still_held.status == :held

    payment = Ash.get!(Emakola.Payments.Payment, hold.payment_id, authorize?: false)
    assert payment.metadata["protection_resolution"] == "refunded_by_staff"

    {:ok, [return]} = Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false)
    assert return.status == :approved
    assert return.refund_amount == hold.amount

    assert [entry] = audit(:protection_refund_initiated)
    assert entry.actor_id == user.id
    assert entry.metadata["hold_id"] == hold.id
  end

  test "refund buyer reopens a merchant-denied return before refunding (complaint escalation)",
       %{conn: conn, store: store} do
    hold = protected_hold!(store)

    {:ok, denied_return} =
      Emakola.Orders.request_return(
        %{store_id: store.id, order_id: hold.order_id, reason: :other},
        authorize?: false
      )

    {:ok, _denied} = Emakola.Orders.deny_return(denied_return, %{}, authorize?: false)

    # The buyer escalates the merchant's denial into a complaint — this is
    # what actually lands a hold in the Frozen queue with a :denied return
    # already on file.
    {:ok, _frozen} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :not_received, complaint_text: "Merchant denied but I never got it"},
        authorize?: false
      )

    {:ok, view, _html} = live(conn, ~p"/platform/protection")

    html =
      view
      |> element("button[phx-click='refund_buyer'][phx-value-id='#{hold.id}']")
      |> render_click()

    assert html =~ "initiated"

    {:ok, [reopened]} = Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false)
    assert reopened.id == denied_return.id
    assert reopened.status == :approved
    assert reopened.refund_amount == hold.amount

    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(hold.payment_id,
        tenant: store.id,
        authorize?: false
      )

    assert still_held.status == :held
  end

  test "refund buyer refuses a second click once the return is already approved, and calls RefundService zero times",
       %{conn: conn, store: store} do
    hold = protected_hold!(store)

    {:ok, _frozen} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :other, complaint_text: "Still investigating"},
        authorize?: false
      )

    {:ok, view, _html} = live(conn, ~p"/platform/protection")

    view
    |> element("button[phx-click='refund_buyer'][phx-value-id='#{hold.id}']")
    |> render_click()

    {:ok, [approved_once]} = Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false)
    assert approved_once.status == :approved

    html =
      view
      |> element("button[phx-click='refund_buyer'][phx-value-id='#{hold.id}']")
      |> render_click()

    assert html =~ "already in progress"

    # No second write reached the Return — same `updated_at` as right after
    # the first (successful) approve proves RefundService.issue/5 (and its
    # internal `approve_return`) was never called the second time.
    {:ok, [still_approved]} = Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false)
    assert still_approved.updated_at == approved_once.updated_at

    assert length(audit(:protection_refund_initiated)) == 1
  end
end
