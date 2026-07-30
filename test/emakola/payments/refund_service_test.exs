defmodule Emakola.Payments.RefundServiceTest do
  @moduledoc """
  The merchant-initiated refund path. This is the first place in the app where
  a merchant can move a customer's money back, so every failure case asserts
  that `payment.refunded_amount` is untouched: the `refund.processed` webhook is
  the single writer of that ledger, and the service only ASKS the gateway.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Mox

  alias Emakola.Orders.Return
  alias Emakola.Payments.GatewayMock
  alias Emakola.Payments.Payment
  alias Emakola.Payments.RefundService

  setup :verify_on_exit!

  setup do
    {merchant, store} = create_merchant_with_store!()
    order = create_order!(store, status: :delivered)

    payment =
      store
      |> create_payment!(order_id: order.id, amount: 50_000)
      |> mark_success!()

    return = create_return!(store, order)

    {:ok, merchant: merchant, store: store, order: order, payment: payment, return: return}
  end

  describe "issue/4 — gateway accepted" do
    test "asks the gateway once for the payment reference and pesewa amount", ctx do
      expect(GatewayMock, :process_refund, fn reference, amount ->
        assert reference == ctx.payment.gateway_reference
        assert amount == 12_500
        {:ok, %{refund_reference: "REF-1"}}
      end)

      assert {:ok, _return} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "Torn seam", refund_dispatch_fee?: false},
                 GatewayMock
               )
    end

    test "approves the return with the amount, notes and at-fault flag", ctx do
      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "Torn seam", refund_dispatch_fee?: true},
                 GatewayMock
               )

      assert approved.status == :approved
      assert approved.refund_amount == 12_500
      assert approved.admin_notes == "Torn seam"
      assert approved.refund_dispatch_fee? == true
    end

    test "does not write the payment ledger — the webhook owns that", ctx do
      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      # Paystack refunds are asynchronous: `refund.processed` arrives later and
      # does the ledger work, including marking the return :refunded.
      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.payment).status == :success
      assert approved.status == :approved
    end
  end

  describe "issue/4 — refused before the gateway" do
    # No `expect/3` is registered in these tests, so ANY call to
    # GatewayMock.process_refund/2 raises Mox.UnexpectedCallError. That is the
    # assertion that the gateway was called zero times.

    test "refuses an amount above the refundable balance", ctx do
      partially_refunded = mark_refunded!(ctx.payment, 30_000)

      assert {:error, :amount_exceeds_refundable} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 20_001, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(partially_refunded).refunded_amount == 30_000
      assert reload(ctx.return).status == :requested
    end

    test "refuses an amount above the full payment", ctx do
      assert {:error, :amount_exceeds_refundable} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 50_001, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end

    test "refuses a blank amount instead of approving a refund of nothing", ctx do
      assert {:error, :invalid_amount} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: nil, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end

    test "refuses a nil return instead of crashing on it", ctx do
      assert {:error, :no_return_selected} =
               RefundService.issue(
                 ctx.merchant,
                 nil,
                 %{refund_amount: 1_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end

    test "refuses a merchant with no membership in the return's store", ctx do
      {outsider, _other_store} = create_merchant_with_store!()

      assert {:error, _reason} =
               RefundService.issue(
                 outsider,
                 ctx.return,
                 %{refund_amount: 1_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end
  end

  describe "issue/4 — the approve write fails" do
    # No `expect/3` is registered in the first test, so ANY call to
    # GatewayMock.process_refund/2 raises Mox.UnexpectedCallError. A gateway
    # refund cannot be un-asked: if the approve fails AFTER the gateway
    # accepted, the transaction rolls the return back to :requested while the
    # customer's money is already moving, and the merchant's natural retry
    # refunds them a second time. Every approve failure must therefore be
    # discovered before the gateway is asked for anything.

    test "asks the gateway zero times when the approve is rejected", ctx do
      # `Return.admin_notes` is capped at 2,000 characters — a merchant pasting
      # a long note is a real, merchant-triggerable approve failure.
      assert {:error, _reason} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{
                   refund_amount: 12_500,
                   admin_notes: String.duplicate("a", 2_001),
                   refund_dispatch_fee?: false
                 },
                 GatewayMock
               )

      assert reload(ctx.return).status == :requested
      assert reload(ctx.payment).refunded_amount == 0
    end

    test "a retry after a rejected approve refunds the customer only once", ctx do
      # Exactly one call is allowed across BOTH attempts. A second reaching the
      # gateway raises Mox.UnexpectedCallError — that IS the "no double refund"
      # assertion, and in production it would be a second real refund.
      expect(GatewayMock, :process_refund, 1, fn _reference, _amount -> {:ok, %{}} end)

      assert {:error, _reason} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{
                   refund_amount: 12_500,
                   admin_notes: String.duplicate("a", 2_001),
                   refund_dispatch_fee?: false
                 },
                 GatewayMock
               )

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{
                   refund_amount: 12_500,
                   admin_notes: "Shorter note",
                   refund_dispatch_fee?: false
                 },
                 GatewayMock
               )

      assert approved.status == :approved
      assert reload(ctx.payment).refunded_amount == 0
    end
  end

  describe "issue/4 — an order charged more than once" do
    test "refunds against the successful charge when an earlier attempt failed", ctx do
      # A customer whose first attempt fails retries checkout, which creates a
      # SECOND Payment row for the same order (`checkout_live`'s retry_payment).
      order = create_order!(ctx.store, status: :delivered)

      ctx.store
      |> create_payment!(order_id: order.id, amount: 50_000)
      |> mark_failed!()

      succeeded =
        ctx.store
        |> create_payment!(order_id: order.id, amount: 50_000)
        |> mark_success!()

      return = create_return!(ctx.store, order)

      expect(GatewayMock, :process_refund, fn reference, amount ->
        assert reference == succeeded.gateway_reference
        assert amount == 12_500
        {:ok, %{}}
      end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert approved.status == :approved
      assert approved.refund_amount == 12_500
    end

    test "does not mistake a fully refunded charge for an uncharged order", ctx do
      # A full refund flips the payment to :refunded. That is still a captured
      # charge with an exhausted balance — treating it as cash on delivery
      # would approve a return that moves no money and say nothing.
      fully_refunded = mark_refunded!(ctx.payment, 50_000)

      assert {:error, :amount_exceeds_refundable} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 1_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(fully_refunded).refunded_amount == 50_000
      assert reload(ctx.return).status == :requested
    end
  end

  describe "issue/4 — concurrent approves" do
    test "a second approve from the same stale struct never reaches the gateway", ctx do
      # Exactly one call is allowed. A second reaching the gateway raises
      # Mox.UnexpectedCallError — that IS the "called once" assertion, and a
      # second real call would refund the customer twice.
      expect(GatewayMock, :process_refund, 1, fn _reference, _amount -> {:ok, %{}} end)

      params = %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false}

      # Both callers hold the struct as it was read: status :requested. This is
      # what two open LiveViews (or a queued double click) actually pass in.
      stale = ctx.return

      assert {:ok, approved} = RefundService.issue(ctx.merchant, stale, params, GatewayMock)
      assert approved.status == :approved

      assert {:error, :already_processed} =
               RefundService.issue(ctx.merchant, stale, params, GatewayMock)

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :approved
    end

    test "refuses a return that has already been denied", ctx do
      denied =
        ctx.return
        |> Ash.Changeset.for_update(:deny, %{})
        |> Ash.update!(authorize?: false)

      # The caller still holds the :requested struct.
      assert {:error, :already_processed} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(denied).status == :denied
      assert reload(ctx.payment).refunded_amount == 0
    end
  end

  describe "issue/4 — cash on delivery (order with no payment)" do
    # No `expect/3` is registered here, so ANY gateway call raises
    # Mox.UnexpectedCallError. There is no charge to reverse: the merchant
    # hands the cash back out of band.

    test "approves a return on an order that was never charged", ctx do
      cod_order = create_order!(ctx.store, status: :delivered)
      cod_return = create_return!(ctx.store, cod_order)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 cod_return,
                 %{
                   refund_amount: 1_000,
                   admin_notes: "Cash returned at the shop",
                   refund_dispatch_fee?: false
                 },
                 GatewayMock
               )

      assert approved.status == :approved
      assert approved.refund_amount == 1_000
      assert approved.admin_notes == "Cash returned at the shop"
      assert reload(cod_return).status == :approved
    end

    test "still refuses a blank amount on an uncharged order", ctx do
      cod_order = create_order!(ctx.store, status: :delivered)
      cod_return = create_return!(ctx.store, cod_order)

      assert {:error, :invalid_amount} =
               RefundService.issue(
                 ctx.merchant,
                 cod_return,
                 %{refund_amount: nil, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(cod_return).status == :requested
    end
  end

  describe "gateway_for/1" do
    test "routes a Hubtel charge back through Hubtel" do
      assert RefundService.gateway_for(%{gateway: :hubtel}) == Emakola.Payments.Gateways.Hubtel
    end

    test "routes every other charge to the configured gateway" do
      configured = Application.get_env(:emakola, :payment_gateway)

      # config/test.exs points :payment_gateway at the in-repo mock gateway;
      # the point is that routing reads config rather than hardcoding Paystack.
      assert configured == Emakola.Payments.Gateways.Mock
      assert RefundService.gateway_for(%{gateway: :paystack}) == configured
    end
  end

  describe "issue/4 — gateway refused" do
    test "maps an unsupported gateway to :gateway_unsupported", ctx do
      expect(GatewayMock, :process_refund, fn _reference, _amount ->
        {:error, :not_supported}
      end)

      assert {:error, :gateway_unsupported} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end

    test "leaves the return requested when the gateway errors", ctx do
      expect(GatewayMock, :process_refund, fn _reference, _amount ->
        {:error, :gateway_down}
      end)

      assert {:error, :gateway_down} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(ctx.payment).refunded_amount == 0
      assert reload(ctx.return).status == :requested
    end
  end

  describe "issue/4 — buyer protection hold" do
    # A fresh order per test (not `ctx.order`) — `ctx.payment` from the
    # top-level setup already carries the oldest `:success` charge on
    # `ctx.order`, and `captured_payment/2` picks the OLDEST captured
    # payment, so reusing `ctx.order` here would refund the wrong payment.
    defp protected_payment!(store, order, attrs \\ %{}) do
      payment =
        store
        |> create_payment!(
          Map.merge(
            %{
              order_id: order.id,
              amount: 50_000,
              payout_held: true,
              payout_hold_reason: "buyer_protection"
            },
            Map.new(attrs)
          )
        )
        |> mark_success!()

      :ok = Emakola.Payments.ProtectionHolds.ensure_hold(payment)

      {:ok, hold} =
        Emakola.Payments.get_protection_hold_by_payment(payment.id,
          tenant: store.id,
          authorize?: false
        )

      {payment, hold}
    end

    defp reload_hold(store, hold) do
      {:ok, reloaded} =
        Emakola.Payments.get_protection_hold_by_payment(hold.payment_id,
          tenant: store.id,
          authorize?: false
        )

      reloaded
    end

    # Gateway acceptance is NOT refund success — Paystack refund-create
    # returns immediately with the refund still `pending`, resolving async
    # (and possibly failing) via `refund.processed`. So `issue/5` must NOT
    # close the hold itself; it only stashes the intended resolution for
    # the webhook to apply once the refund is actually confirmed. This is
    # the corrected behavior — the RED for the old (wrong) "closes
    # immediately" behavior is exactly this: the hold stays `:held`.
    test "a full refund does not close the hold — it stashes the resolution for the webhook",
         ctx do
      order = create_order!(ctx.store, status: :delivered)
      {payment, hold} = protected_payment!(ctx.store, order)
      return = create_return!(ctx.store, order)

      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 return,
                 %{refund_amount: 50_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert approved.status == :approved

      reloaded = reload_hold(ctx.store, hold)
      assert reloaded.status == :held
      assert is_nil(reloaded.resolution)

      assert reload(payment).metadata["protection_resolution"] == "merchant_refunded"
    end

    test "a full refund with an explicit resolution stashes THAT resolution (Task 12's seam)",
         ctx do
      order = create_order!(ctx.store, status: :delivered)
      {payment, _hold} = protected_payment!(ctx.store, order)
      return = create_return!(ctx.store, order)

      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, _approved} =
               RefundService.issue(
                 ctx.merchant,
                 return,
                 %{refund_amount: 50_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock,
                 resolution: :refunded_by_staff
               )

      assert reload(payment).metadata["protection_resolution"] == "refunded_by_staff"
    end

    test "a partial refund leaves the hold held and stashes nothing", ctx do
      order = create_order!(ctx.store, status: :delivered)
      {payment, hold} = protected_payment!(ctx.store, order)
      return = create_return!(ctx.store, order)

      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 return,
                 %{refund_amount: 12_500, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert approved.status == :approved

      reloaded = reload_hold(ctx.store, hold)
      assert reloaded.status == :held
      assert is_nil(reloaded.resolution)

      refute Map.has_key?(reload(payment).metadata, "protection_resolution")
    end

    test "a refund on a payment with no protection hold is untouched", ctx do
      # `ctx.payment` (top-level setup) was never routed through
      # `ProtectionHolds.ensure_hold` — no hold row exists for it at all,
      # the ordinary case for the vast majority of payments.
      expect(GatewayMock, :process_refund, fn _reference, _amount -> {:ok, %{}} end)

      assert {:ok, approved} =
               RefundService.issue(
                 ctx.merchant,
                 ctx.return,
                 %{refund_amount: 50_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert approved.status == :approved

      # `get?: true` read actions return `{:error, NotFound}` (wrapped in
      # `Ash.Error.Invalid`), not `{:ok, nil}`, when nothing matches.
      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Payments.get_protection_hold_by_payment(ctx.payment.id,
                 tenant: ctx.store.id,
                 authorize?: false
               )

      refute Map.has_key?(reload(ctx.payment).metadata, "protection_resolution")
    end
  end

  # ── Helpers ──

  defp mark_success!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp mark_failed!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update!(authorize?: false)
  end

  defp mark_refunded!(payment, amount) do
    payment
    |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: amount})
    |> Ash.update!(authorize?: false)
  end

  defp create_return!(store, order) do
    Return
    |> Ash.Changeset.for_create(:request_return, %{
      store_id: store.id,
      order_id: order.id,
      reason: :defective
    })
    |> Ash.create!(authorize?: false)
  end

  defp reload(%Payment{} = payment), do: Ash.get!(Payment, payment.id, authorize?: false)
  defp reload(%Return{} = return), do: Ash.get!(Return, return.id, authorize?: false)
end
