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

    test "returns :payment_not_found when the order was never paid", ctx do
      unpaid_order = create_order!(ctx.store, status: :delivered)
      unpaid_return = create_return!(ctx.store, unpaid_order)

      assert {:error, :payment_not_found} =
               RefundService.issue(
                 ctx.merchant,
                 unpaid_return,
                 %{refund_amount: 1_000, admin_notes: "", refund_dispatch_fee?: false},
                 GatewayMock
               )

      assert reload(unpaid_return).status == :requested
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

  # ── Helpers ──

  defp mark_success!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
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
