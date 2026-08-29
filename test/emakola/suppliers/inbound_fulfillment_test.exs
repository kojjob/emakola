defmodule Emakola.Suppliers.InboundFulfillmentTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  alias Emakola.Payments
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.Workers.ProtectionReleaseWorker
  alias Emakola.Suppliers.InboundFulfillment

  setup :verify_on_exit!

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Inbound supplier"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Selling store"})
    customer = create_customer!(reseller, phone: "+233501234567")

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: reseller.id,
          customer_id: customer.id,
          shipping_address: %{"phone" => customer.phone, "city" => "Accra"}
        },
        authorize?: false
      )

    supplier = create_supplier!(reseller, linked_store_id: wholesaler.id)
    fulfillment = create_fulfillment!(order, reseller, supplier_id: supplier.id)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      reseller_actor: reseller_actor,
      reseller: reseller,
      order: order,
      fulfillment: fulfillment
    }
  end

  test "wholesaler sees linked fulfillments across the reseller tenant", context do
    assert {:ok, [fulfillment]} =
             InboundFulfillment.list(context.wholesaler_actor, context.wholesaler.id)

    assert fulfillment.id == context.fulfillment.id
    assert fulfillment.order.id == context.order.id
    assert fulfillment.store_id == context.reseller.id
  end

  test "unrelated merchants cannot read or mutate inbound fulfillments", context do
    {outsider, outsider_store} = create_merchant_with_store!()

    assert {:error, :forbidden} =
             InboundFulfillment.list(outsider, context.wholesaler.id)

    assert {:error, :not_found} =
             InboundFulfillment.get(outsider, outsider_store.id, context.fulfillment.id)
  end

  test "supplier ships and completes delivery using the customer OTP", context do
    assert {:ok, shipped} =
             InboundFulfillment.mark_shipped(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               "GH-TRACK-44"
             )

    assert shipped.status == :shipped

    parent = self()

    expect(Emakola.SMSProviderMock, :send_sms, fn phone, message, opts ->
      assert phone == "+233501234567"
      assert opts[:store_id] == context.reseller.id
      [code] = Regex.run(~r/delivery code is (\d{6})/, message, capture: :all_but_first)
      send(parent, {:delivery_code, code})
      {:ok, %{id: "sms-1"}}
    end)

    assert {:ok, proof} =
             InboundFulfillment.request_delivery_code(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id
             )

    assert String.ends_with?(proof.sent_to, "4567")
    refute proof.sent_to == "+233501234567"
    assert_receive {:delivery_code, code}

    assert {:error, :invalid_code} =
             InboundFulfillment.verify_delivery(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               "000000"
             )

    attempted = Ash.get!(Emakola.Orders.FulfillmentDeliveryProof, proof.id, authorize?: false)
    assert attempted.attempts == 1

    assert {:ok, delivered} =
             InboundFulfillment.verify_delivery(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               code
             )

    assert delivered.status == :delivered

    verified = Ash.get!(Emakola.Orders.FulfillmentDeliveryProof, proof.id, authorize?: false)
    assert %DateTime{} = verified.verified_at
  end

  # Regression test for a critical review finding: `verify_delivery/4` wraps
  # `:verify` in its OWN `Repo.transaction`, still open when the
  # `ReleaseProtectionHoldOnVerify` hook fires. The OLD design released the
  # protection hold synchronously from that hook — `ProtectionRelease.release/2`
  # opens a nested `Repo.transaction` and calls `Repo.rollback` on failure,
  # which (Ecto nested transactions share the outer connection; there's no
  # real savepoint here) can leave the connection unable to run the very
  # next statement, `mark_fulfillment_delivered!`, tearing down the whole
  # verification even though the release failure itself was caught and
  # logged. The fix decouples release into `ProtectionReleaseWorker`: the
  # hook only enqueues (a plain insert, never `Repo.rollback`), so this full
  # real-caller flow — outer transaction and all — must complete cleanly
  # regardless of what the (separately-run) release worker later does.
  test "verify_delivery completes through its real outer transaction for a protected order, and separately enqueues the release",
       context do
    order = Ash.get!(Emakola.Orders.Order, context.order.id, authorize?: false)

    payment =
      context.reseller
      |> create_payment!(%{
        order_id: order.id,
        amount: 25_000,
        payout_held: true,
        payout_hold_reason: "buyer_protection"
      })
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    :ok = ProtectionHolds.ensure_hold(payment)

    assert {:ok, _shipped} =
             InboundFulfillment.mark_shipped(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               "GH-TRACK-45"
             )

    parent = self()

    expect(Emakola.SMSProviderMock, :send_sms, fn _phone, message, _opts ->
      [code] = Regex.run(~r/delivery code is (\d{6})/, message, capture: :all_but_first)
      send(parent, {:delivery_code, code})
      {:ok, %{id: "sms-2"}}
    end)

    assert {:ok, _proof} =
             InboundFulfillment.request_delivery_code(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id
             )

    assert_receive {:delivery_code, code}

    # The critical assertion: verify_delivery/4 — the real caller, its own
    # outer Repo.transaction and all — must complete cleanly and actually
    # mark the fulfillment delivered. Under the old synchronous-release
    # design, a poisoned connection would surface here as an exception
    # (or a broken transaction) instead of this clean {:ok, _}.
    assert {:ok, delivered} =
             InboundFulfillment.verify_delivery(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               code
             )

    assert delivered.status == :delivered

    args = %{
      "order_id" => order.id,
      "store_id" => context.reseller.id,
      "reason" => "delivery_otp"
    }

    assert_enqueued(worker: ProtectionReleaseWorker, args: args)

    # The release itself runs later, in the worker's own connection —
    # separately from (and unable to affect) the verification above.
    assert :ok = perform_job(ProtectionReleaseWorker, args)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id,
        tenant: context.reseller.id,
        authorize?: false
      )

    assert released_hold.status == :released
    assert released_hold.release_reason == :delivery_otp

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == false
    assert reloaded_payment.payable_amount == released_hold.net
  end

  test "delivery code cannot be requested before shipment", context do
    assert {:error, :fulfillment_not_shipped} =
             InboundFulfillment.request_delivery_code(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id
             )
  end
end
