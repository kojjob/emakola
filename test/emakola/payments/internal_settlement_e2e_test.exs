defmodule Emakola.Payments.InternalSettlementE2ETest do
  @moduledoc """
  Phase 3 gate: one composed test walking the full internal-rail journey for
  an UNVERIFIED store, sum-exact at every stage — the "does the whole thing
  actually connect end to end" proof that the per-unit tests
  (order_settlement_internal_test.exs, internal_payout_service_test.exs,
  supplier_ledger_unification_test.exs) each cover in isolation but never
  chain together.

  Drives checkout via the service layer (`CheckoutService.checkout!/3` +
  `OrderSettlement.prepare/2` + `persist_payment/2`) rather than the LiveView
  — that pass-through is already pinned by
  `checkout_live_test.exs`'s "internal rail settlement" describe block, so
  going through the gateway/Mox layer here would only add LiveView overhead
  with no new coverage. No `payment_gateway` swap is needed either, since
  this path never calls a gateway — `async: false` is kept anyway to match
  this suite family's convention.

  Journey: checkout -> :internal payment (STAGE 1) -> charge.success settles
  the splits (STAGE 2) -> prepare_internal_payout claims the payable balance
  (STAGE 3) -> transfer.success finalizes the payout, splits stay claimed
  (STAGE 4). Then a twin run through a VERIFIED store (identical order shape)
  proves its platform-fee allocation is numerically identical to the
  unverified run's — the fee-parity guarantee `prepare/2`'s moduledoc
  promises between the `:internal` and `:platform_fee` rails.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Payments.{OrderSettlement, PaymentSplit, PayoutService}
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  # -- fixtures (mirrored from internal_payout_service_test.exs /
  # order_settlement_internal_test.exs / supplier_ledger_unification_test.exs)

  defp momo_destination!(store) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244000111",
        "account_name" => "Test Merchant"
      }
    })
    |> Ash.create!(authorize?: false)
  end

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  defp checkout_own_stock_order!(store) do
    product = create_product!(store, title: "E2E Internal Settlement")

    variant =
      create_variant!(product, store,
        price: 5_000,
        sku: "E2E-#{System.unique_integer([:positive])}",
        stock_quantity: 20
      )

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 2}],
        []
      )

    order
  end

  defp charge_success!(payment) do
    perform_job(PaystackWebhookHandler, %{
      "event" => "charge.success",
      "data" => %{"reference" => payment.gateway_reference}
    })
  end

  defp transfer_success!(payout) do
    perform_job(PaystackWebhookHandler, %{
      "event" => "transfer.success",
      "data" => %{"reference" => payout.transfer_reference, "status" => "success"}
    })
  end

  test "composed internal-rail journey: checkout -> settle -> payout -> transfer, with exact fee parity to the verified/gateway rail" do
    # -- UNVERIFIED store: no StorePayoutAccount verification, but a MoMo
    # transfer destination is on file so the eventual payout can pay out.
    store = create_store!(name: "E2E Unverified Store")
    momo_destination!(store)

    order = checkout_own_stock_order!(store)
    settlement = OrderSettlement.prepare(order.id, store.id)

    assert {:split, %{mode: :internal, allocations: allocations, shares: []}} = settlement

    {:ok, payment} =
      OrderSettlement.persist_payment(
        %{
          store_id: store.id,
          order_id: order.id,
          amount: order.total,
          currency: store.currency,
          gateway: :paystack,
          gateway_reference: "PAY-e2e-internal-#{System.unique_integer([:positive])}",
          split_mode: :internal
        },
        settlement
      )

    # STAGE 1: real checkout lands on the internal rail; Σ splits == order.total.
    assert payment.split_mode == :internal

    {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    assert Enum.sum(Enum.map(splits, & &1.amount)) == order.total

    merchant_alloc = Enum.find(allocations, &(&1.role == :merchant))
    platform_alloc = Enum.find(allocations, &(&1.role == :platform))
    refute is_nil(merchant_alloc)
    refute is_nil(platform_alloc)

    # STAGE 2: charge.success settles every split.
    assert :ok = charge_success!(payment)

    {:ok, settled_splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    assert Enum.all?(settled_splits, &(&1.status == :settled))

    merchant_split = Enum.find(settled_splits, &(&1.role == :merchant))
    refute is_nil(merchant_split)
    expected_payable = PaymentSplit.frozen_paid_amount(merchant_split)
    assert expected_payable == merchant_alloc.amount

    # STAGE 3: PayoutService claims the store's payable internal balance.
    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
    assert payout.amount == expected_payable
    assert payout.basis == :allocations

    # STAGE 4: transfer.success finalizes the payout; the split stays claimed.
    assert :ok = transfer_success!(payout)

    reloaded_payout = Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false)
    assert reloaded_payout.status == :paid

    reloaded_split = Ash.get!(PaymentSplit, merchant_split.id, authorize?: false)
    assert reloaded_split.status == :settled
    assert reloaded_split.payout_id == payout.id
    refute is_nil(reloaded_split.paid_out_at)

    # -- Twin run: identical order shape through a VERIFIED store — the
    # gateway rail. Parity assertion: same platform-fee allocation, exactly.
    verified_store = create_store!(name: "E2E Verified Store")
    verified_payout!(verified_store, "ACCT_e2e_verified")

    verified_order = checkout_own_stock_order!(verified_store)

    assert {:split, %{mode: :platform_fee, allocations: verified_allocations}} =
             OrderSettlement.prepare(verified_order.id, verified_store.id)

    verified_platform_alloc = Enum.find(verified_allocations, &(&1.role == :platform))
    refute is_nil(verified_platform_alloc)

    assert verified_platform_alloc.amount == platform_alloc.amount
  end
end
