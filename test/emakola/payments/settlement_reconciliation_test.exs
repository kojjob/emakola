defmodule Emakola.Payments.SettlementReconciliationTest do
  @moduledoc """
  Paystack `settlement` events reconcile the split ledger against money that
  actually moved.

  `:settled` on a PaymentSplit means "the gateway accepted the charge" — set by
  `charge.success`. It does NOT mean the money reached the merchant's account:
  that happens later, when Paystack pays out a settlement batch. Those
  `settlement` events used to fall into the unknown-event clause and be silently
  dropped, and `paystack_split_reference` was never populated by anything.

  The reconciliation never guesses which charges were in a batch: it fetches the
  settlement's transaction list from the documented Settlement API and stamps
  only the splits whose payment reference appears there, and only the splits
  routed to the settlement's destination (the subaccount for a subaccount
  settlement, the platform's nil-subaccount rows for a main-account one).
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  setup :verify_on_exit!

  setup do
    store = Emakola.Factory.create_store!()

    payment =
      store
      |> Emakola.Factory.create_payment!(%{amount: 500_000, split_mode: :platform_fee})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    merchant_split =
      split!(store, payment, %{role: :merchant, amount: 490_000, subaccount_code: "SUB_m"})

    platform_split = split!(store, payment, %{role: :platform, amount: 10_000})

    %{
      store: store,
      payment: payment,
      merchant_split: settle!(merchant_split),
      platform_split: settle!(platform_split)
    }
  end

  defp split!(store, payment, attrs) do
    Emakola.Payments.create_payment_split!(
      Map.merge(%{store_id: store.id, payment_id: payment.id}, attrs),
      authorize?: false
    )
  end

  defp settle!(split) do
    split
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp fresh(split) do
    Ash.get!(PaymentSplit, split.id, authorize?: false, tenant: split.store_id)
  end

  defp settlement_event(data) do
    %{"event" => "settlement", "data" => data}
  end

  defp transactions_page(references) do
    {:ok,
     %{
       "status" => true,
       "data" => Enum.map(references, &%{"reference" => &1, "status" => "success"}),
       "meta" => %{"page" => 1, "pageCount" => 1}
     }}
  end

  describe "a subaccount settlement" do
    test "stamps the splits routed to that subaccount, and only those", ctx do
      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, fn 4321, 1 ->
        transactions_page([ctx.payment.gateway_reference])
      end)

      event =
        settlement_event(%{
          "id" => 4321,
          "subaccount" => %{"subaccount_code" => "SUB_m"}
        })

      assert :ok = perform_job(PaystackWebhookHandler, event)

      assert fresh(ctx.merchant_split).paystack_split_reference == "4321"
      # The platform's cut settles to the main account, not this subaccount.
      assert fresh(ctx.platform_split).paystack_split_reference == nil
    end

    test "is idempotent — a redelivered event does not restamp", ctx do
      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, 2, fn 4321, 1 ->
        transactions_page([ctx.payment.gateway_reference])
      end)

      event =
        settlement_event(%{"id" => 4321, "subaccount" => %{"subaccount_code" => "SUB_m"}})

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert :ok = perform_job(PaystackWebhookHandler, event)

      assert fresh(ctx.merchant_split).paystack_split_reference == "4321"
    end
  end

  describe "a main-account settlement" do
    test "stamps the platform's nil-subaccount splits", ctx do
      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, fn 99, 1 ->
        transactions_page([ctx.payment.gateway_reference])
      end)

      assert :ok = perform_job(PaystackWebhookHandler, settlement_event(%{"id" => 99}))

      assert fresh(ctx.platform_split).paystack_split_reference == "99"
      assert fresh(ctx.merchant_split).paystack_split_reference == nil
    end
  end

  describe "defenses" do
    test "a still-pending split is never stamped — settlement proof cannot precede the charge",
         ctx do
      pending = split!(ctx.store, ctx.payment, %{role: :dropshipper, amount: 1_000})

      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, fn 7, 1 ->
        transactions_page([ctx.payment.gateway_reference])
      end)

      assert :ok = perform_job(PaystackWebhookHandler, settlement_event(%{"id" => 7}))

      assert fresh(pending).paystack_split_reference == nil
      assert fresh(pending).status == :pending
    end

    test "a transaction reference we did not charge is skipped" do
      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, fn 8, 1 ->
        transactions_page(["ref-that-is-not-ours"])
      end)

      assert :ok = perform_job(PaystackWebhookHandler, settlement_event(%{"id" => 8}))
    end

    test "a settlement event without an id is logged and dropped" do
      assert :ok = perform_job(PaystackWebhookHandler, settlement_event(%{}))
    end

    test "a gateway error is returned for retry" do
      expect(Emakola.Payments.PaystackClientMock, :list_settlement_transactions, fn 10, 1 ->
        {:error, :timeout}
      end)

      assert {:error, _} = perform_job(PaystackWebhookHandler, settlement_event(%{"id" => 10}))
    end

    test "pagination walks every page", ctx do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_settlement_transactions, fn 11, 1 ->
        {:ok,
         %{
           "status" => true,
           "data" => [%{"reference" => "not-ours", "status" => "success"}],
           "meta" => %{"page" => 1, "pageCount" => 2}
         }}
      end)
      |> expect(:list_settlement_transactions, fn 11, 2 ->
        {:ok,
         %{
           "status" => true,
           "data" => [%{"reference" => ctx.payment.gateway_reference, "status" => "success"}],
           "meta" => %{"page" => 2, "pageCount" => 2}
         }}
      end)

      assert :ok = perform_job(PaystackWebhookHandler, settlement_event(%{"id" => 11}))

      assert fresh(ctx.platform_split).paystack_split_reference == "11"
    end
  end
end
