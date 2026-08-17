defmodule Emakola.Payments.RefundLiabilityTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.RefundLiability

  setup do
    seller = create_store!(name: "Recovering seller")
    original_store = create_store!(name: "Original checkout")
    original_payment = create_payment!(original_store)

    liability =
      create_split!(original_store, original_payment, %{
        role: :wholesaler,
        recipient_store_id: seller.id,
        amount: 1_000
      })
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 700})
      |> Ash.update!(authorize?: false)

    {:ok, seller: seller, original_store: original_store, liability: liability}
  end

  test "reserves debt from future earnings without changing the charge total", %{
    seller: seller,
    liability: liability
  } do
    allocations = RefundLiability.reserve!(allocations(seller, 500, 100))
    by_role = Map.new(allocations, &{&1.role, &1})

    assert by_role.merchant.amount == 0
    assert by_role.merchant.recovery_amount == 500
    assert by_role.platform.amount == 600
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == 600

    assert fresh(liability).reserved_recovery_amount == 500
    assert fresh(liability).recovered_amount == 0
  end

  test "a second reservation cannot claim an amount already reserved", %{
    seller: seller,
    liability: liability
  } do
    first = RefundLiability.reserve!(allocations(seller, 500, 100))
    second = RefundLiability.reserve!(allocations(seller, 500, 100))

    assert allocation(first, :merchant).recovery_amount == 500
    assert allocation(second, :merchant).recovery_amount == 200
    assert fresh(liability).reserved_recovery_amount == 700
  end

  test "releases a reservation when payment initiation fails", %{
    seller: seller,
    liability: liability
  } do
    reserved = RefundLiability.reserve!(allocations(seller, 500, 100))
    assert fresh(liability).reserved_recovery_amount == 500

    assert :ok = RefundLiability.release!(reserved)
    assert fresh(liability).reserved_recovery_amount == 0
    assert fresh(liability).recovered_amount == 0
  end

  test "applies a successful recovery exactly once", %{
    seller: seller,
    liability: liability
  } do
    [merchant | _] = RefundLiability.reserve!(allocations(seller, 500, 100))
    payment = create_payment!(seller, amount: 600)

    earning =
      create_split!(seller, payment, %{
        role: :merchant,
        recipient_store_id: seller.id,
        amount: merchant.amount,
        recovery_amount: merchant.recovery_amount,
        recovery_breakdown: merchant.recovery_breakdown
      })

    assert :ok = RefundLiability.apply_recoveries!([earning])
    assert :ok = RefundLiability.apply_recoveries!([earning])

    updated_liability = fresh(liability)
    assert updated_liability.recovered_amount == 500
    assert updated_liability.reserved_recovery_amount == 0
    assert fresh(earning).recovery_applied_amount == 500
  end

  test "reopens recovery proportionally when the earning is refunded", %{
    seller: seller,
    liability: liability
  } do
    [merchant | _] = RefundLiability.reserve!(allocations(seller, 500, 100))
    payment = create_payment!(seller, amount: 600)

    earning =
      create_split!(seller, payment, %{
        role: :merchant,
        recipient_store_id: seller.id,
        amount: merchant.amount,
        recovery_amount: merchant.recovery_amount,
        recovery_breakdown: merchant.recovery_breakdown
      })

    RefundLiability.apply_recoveries!([earning])
    assert fresh(liability).recovered_amount == 500

    RefundLiability.rollback_recoveries!(%{payment | refunded_amount: 300}, [earning])
    assert fresh(liability).recovered_amount == 250
    assert fresh(earning).recovery_reversed_amount == 250

    RefundLiability.rollback_recoveries!(%{payment | refunded_amount: 600}, [earning])
    assert fresh(liability).recovered_amount == 0
    assert fresh(earning).recovery_reversed_amount == 500
  end

  defp allocations(store, earning, platform) do
    [
      %{
        role: :merchant,
        recipient_store_id: store.id,
        subaccount_code: "ACCT_seller",
        amount: earning
      },
      %{role: :platform, recipient_store_id: nil, subaccount_code: nil, amount: platform}
    ]
  end

  defp allocation(allocations, role), do: Enum.find(allocations, &(&1.role == role))

  # Post-merge hardening (2026-07-11 review): per-split floor division left up
  # to n-1 pesewas of a partial refund unrecoverable. Reversals must sum
  # exactly to the refunded amount.
  describe "exact partial-refund reversals" do
    test "reversals sum exactly to the refunded amount", %{original_store: store} do
      payment = create_payment!(store, amount: 1_001)
      recipient = create_store!(name: "Split recipient")

      splits =
        for amount <- [333, 333, 335] do
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: recipient.id,
            # Real wholesaler splits always carry a supplier: SplitCalculator
            # groups by supplier_id, one row each. The unique_allocation
            # constraint enforces that shape here too.
            supplier_id: Ash.UUID.generate(),
            amount: amount
          })
        end

      RefundLiability.reconcile!(%{payment | refunded_amount: 500}, splits)

      assert splits |> Enum.map(&fresh(&1).reversed_amount) |> Enum.sum() == 500
    end

    test "successive partial refunds keep the running total exact", %{original_store: store} do
      payment = create_payment!(store, amount: 1_001)
      recipient = create_store!(name: "Split recipient two")

      splits =
        for amount <- [333, 333, 335] do
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: recipient.id,
            # Real wholesaler splits always carry a supplier: SplitCalculator
            # groups by supplier_id, one row each. The unique_allocation
            # constraint enforces that shape here too.
            supplier_id: Ash.UUID.generate(),
            amount: amount
          })
        end

      RefundLiability.reconcile!(%{payment | refunded_amount: 500}, splits)
      RefundLiability.reconcile!(%{payment | refunded_amount: 1_001}, reread(splits))

      # A full refund reverses every split completely — no pesewa left behind.
      assert Enum.map(splits, &fresh(&1).reversed_amount) == [333, 333, 335]
    end
  end

  # A supplier that has already DISPATCHED keeps its dispatch fee when the
  # order is refunded — the courier cost is real and already spent. The
  # refunding merchant's own (:dropshipper) split absorbs that portion of the
  # reversal. Every test asserts the invariant: the reversals sum exactly to
  # `payment.refunded_amount`. On a full refund each reversal equals its base,
  # so those tests also assert `Σ base == payment.amount` directly.
  describe "dispatch-fee protection" do
    setup do
      store = create_store!(name: "Dispatch protection store")
      order = create_order!(store)
      payment = create_payment!(store, amount: 10_000, order_id: order.id)
      supplier = create_supplier!(store, name: "Dispatched supplier")

      {:ok, store: store, order: order, payment: payment, supplier: supplier}
    end

    test "a shipped supplier's dispatch fee shifts onto the dropshipper", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      # bases: wholesaler 6_000 - 500, dropshipper 3_000 + 500, platform 1_000
      assert reversals(splits) == [5_500, 3_500, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "a supplier that has not dispatched keeps today's proportional numbers", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :pending,
        dispatch_fee: 500
      })

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [6_000, 3_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "only the dispatched supplier is protected when suppliers differ", ctx do
      %{store: store, order: order, payment: payment, supplier: delivered_supplier} = ctx
      notified_supplier = create_supplier!(store, name: "Notified supplier")

      create_fulfillment!(order, store, %{
        supplier_id: delivered_supplier.id,
        status: :delivered,
        dispatch_fee: 400
      })

      create_fulfillment!(order, store, %{
        supplier_id: notified_supplier.id,
        status: :notified,
        dispatch_fee: 300
      })

      splits = [
        create_split!(store, payment, %{
          role: :wholesaler,
          supplier_id: delivered_supplier.id,
          amount: 4_000
        }),
        create_split!(store, payment, %{
          role: :wholesaler,
          supplier_id: notified_supplier.id,
          amount: 3_000
        }),
        create_split!(store, payment, %{role: :dropshipper, amount: 2_000}),
        create_split!(store, payment, %{role: :platform, amount: 1_000})
      ]

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      # Only the :delivered supplier's 400 is protected; the :notified one's 300 is not.
      assert reversals(splits) == [3_600, 3_000, 2_400, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "protection scales through a partial refund", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 4_000}, splits)

      # 40% of each protected base: 5_500, 3_500, 1_000
      assert reversals(splits) == [2_200, 1_400, 400]
      assert Enum.sum(reversals(splits)) == 4_000

      # Driving the same splits to a full refund exposes the bases themselves,
      # proving Σ base == payment.amount — the equality the invariant rests on.
      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, reread(splits))

      assert reversals(splits) == [5_500, 3_500, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "cumulative partial refunds never double-count the protected fee", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 3_000}, splits)

      assert reversals(splits) == [1_650, 1_050, 300]
      assert Enum.sum(reversals(splits)) == 3_000

      # `refunded_amount` is cumulative at the gateway: a second 30% refund
      # arrives as 6_000 total, and reversals must land on 60% of each base.
      RefundLiability.reconcile!(%{payment | refunded_amount: 6_000}, reread(splits))

      assert reversals(splits) == [3_300, 2_100, 600]
      assert Enum.sum(reversals(splits)) == 6_000
    end

    test "a supplier-at-fault return waives the protection", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      approve_return!(store, order, refund_dispatch_fee?: true)
      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [6_000, 3_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "a return that does not blame the supplier leaves protection intact", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      approve_return!(store, order, refund_dispatch_fee?: false)
      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [5_500, 3_500, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "falls back to plain amounts when the payment has no order", ctx do
      %{store: store, order: order, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      orderless_payment = create_payment!(store, amount: 10_000)
      splits = standard_splits(store, orderless_payment, supplier)

      RefundLiability.reconcile!(%{orderless_payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [6_000, 3_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "falls back to plain amounts when the order has no fulfillments", ctx do
      %{store: store, payment: payment, supplier: supplier} = ctx

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [6_000, 3_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "falls back to plain amounts when every dispatch fee is zero", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 0
      })

      splits = standard_splits(store, payment, supplier)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [6_000, 3_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "falls back to plain amounts when there is no dropshipper split", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      splits = [
        create_split!(store, payment, %{
          role: :wholesaler,
          supplier_id: supplier.id,
          amount: 9_000
        }),
        create_split!(store, payment, %{role: :platform, amount: 1_000})
      ]

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      assert reversals(splits) == [9_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000
    end

    test "a dispatch fee larger than the split is clamped to the split amount", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 2_000
      })

      splits = [
        create_split!(store, payment, %{role: :wholesaler, supplier_id: supplier.id, amount: 500}),
        create_split!(store, payment, %{role: :dropshipper, amount: 8_500}),
        create_split!(store, payment, %{role: :platform, amount: 1_000})
      ]

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)

      # min(2_000, 500) = 500 protected — the wholesaler base floors at 0, never negative.
      assert reversals(splits) == [0, 9_000, 1_000]
      assert Enum.sum(reversals(splits)) == 10_000

      # The dropshipper absorbs more than its own allocation. That over-reversal
      # is intended and representable — clamping it would break the invariant.
      [_wholesaler, dropshipper, _platform] = splits
      assert fresh(dropshipper).reversed_amount > dropshipper.amount
      assert fresh(dropshipper).status == :reversed
    end
  end

  # Protection is derived from MUTABLE state (Fulfillment.status,
  # Return.refund_dispatch_fee?), but `record_reversal` only ever ratchets
  # upward. If a later refund event re-derived the bases, a split whose new
  # target had dropped would stay frozen at its old, higher figure while the
  # others advanced — and the recorded total would exceed the money actually
  # refunded. The fix pins the protection at the FIRST reversal, so both
  # directions of a mid-refund state flip are inert.
  describe "protection is pinned at the first reversal" do
    setup do
      store = create_store!(name: "Pinned protection store")
      order = create_order!(store)
      payment = create_payment!(store, amount: 10_000, order_id: order.id)
      supplier = create_supplier!(store, name: "Pinned supplier")

      {:ok, store: store, order: order, payment: payment, supplier: supplier}
    end

    test "waiving the fee after a partial refund does not claw the fee twice", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier.id,
        status: :shipped,
        dispatch_fee: 500
      })

      splits = standard_splits(store, payment, supplier)

      # 90% against protected bases 5_500 / 3_500 / 1_000.
      RefundLiability.reconcile!(%{payment | refunded_amount: 9_000}, splits)
      assert reversals(splits) == [4_950, 3_150, 900]

      # Only NOW does the merchant approve the return blaming the supplier.
      approve_return!(store, order, refund_dispatch_fee?: true)

      RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, reread(splits))

      # Re-deriving here would target the unprotected 6_000/3_000/1_000, and
      # the dropshipper — already at 3_150 — would freeze above its new 3_000
      # target while the other two advanced, recording 10_150 on a 10_000
      # payment. The pin keeps the original bases in force.
      assert Enum.sum(reversals(splits)) == 10_000
      assert reversals(splits) == [5_500, 3_500, 1_000]
    end

    test "a fulfillment dispatching between two partials does not claw twice", ctx do
      %{store: store, order: order, payment: payment, supplier: supplier} = ctx

      fulfillment =
        create_fulfillment!(order, store, %{
          supplier_id: supplier.id,
          status: :pending,
          dispatch_fee: 500
        })

      splits = standard_splits(store, payment, supplier)

      # 90% against unprotected bases 6_000 / 3_000 / 1_000 — nothing had shipped.
      RefundLiability.reconcile!(%{payment | refunded_amount: 9_000}, splits)
      assert reversals(splits) == [5_400, 2_700, 900]

      # The supplier ships between the two refund events.
      fulfillment
      |> Ash.Changeset.for_update(:mark_shipped, %{})
      |> Ash.update!(authorize?: false)

      RefundLiability.reconcile!(%{payment | refunded_amount: 9_500}, reread(splits))

      # The mirror image: protection turning ON would drop the wholesaler's
      # target to 5_225, below the 5_400 already on record, freezing it and
      # recording 9_675 against a 9_500 refund.
      assert Enum.sum(reversals(splits)) == 9_500
      assert reversals(splits) == [5_700, 2_850, 950]
    end
  end

  # Post-review hardening (2026-07-25): the derive branch pinned each split's
  # protected_dispatch_fee with its own `pin_fee!` write, unwrapped by a
  # transaction. If the process died between two of those writes and Oban
  # retried the webhook, `pinned?/1` would see the surviving pin and take the
  # pinned path forever — permanently freezing the OTHER split's protection at
  # zero. Wrapping the writes in `Emakola.Repo.transaction` makes the pin
  # all-or-nothing: a failure partway through must leave every split unpinned.
  describe "derive-branch pins are atomic across splits" do
    setup do
      store = create_store!(name: "Atomic pin store")
      order = create_order!(store)
      payment = create_payment!(store, amount: 10_000, order_id: order.id)
      supplier_a = create_supplier!(store, name: "Atomic supplier A")
      supplier_b = create_supplier!(store, name: "Atomic supplier B")

      {:ok,
       store: store,
       order: order,
       payment: payment,
       supplier_a: supplier_a,
       supplier_b: supplier_b}
    end

    test "a write failing partway through the pin loop leaves no split pinned", ctx do
      %{
        store: store,
        order: order,
        payment: payment,
        supplier_a: supplier_a,
        supplier_b: supplier_b
      } = ctx

      create_fulfillment!(order, store, %{
        supplier_id: supplier_a.id,
        status: :shipped,
        dispatch_fee: 500
      })

      create_fulfillment!(order, store, %{
        supplier_id: supplier_b.id,
        status: :shipped,
        dispatch_fee: 300
      })

      [first, second] =
        [
          create_split!(store, payment, %{
            role: :wholesaler,
            supplier_id: supplier_a.id,
            amount: 5_000
          }),
          create_split!(store, payment, %{
            role: :wholesaler,
            supplier_id: supplier_b.id,
            amount: 4_000
          })
        ]
        |> Enum.sort_by(& &1.id)

      dropshipper = create_split!(store, payment, %{role: :dropshipper, amount: 1_000})

      # Delete the split that sorts second (reconcile!/2 processes splits in
      # id order), so `first`'s pin write commits before the loop reaches
      # `second` and raises — a clean stand-in for a crash between two
      # `pin_fee!` calls without contorting production code to allow it.
      Emakola.Repo.delete_all(
        Ecto.Query.from(s in "payment_splits", where: s.id == type(^second.id, Ecto.UUID))
      )

      splits = [first, second, dropshipper]

      # `Ash.update!`'s failure surfaces as a MatchError on the `{:ok, _}`
      # unwrap (same as `reserve!`/`release!`/`apply_recovery!` above) rather
      # than the underlying Ash error, because the rollback this triggers is
      # caught by the outermost `Repo.transaction` — ours.
      assert_raise MatchError, fn ->
        RefundLiability.reconcile!(%{payment | refunded_amount: 10_000}, splits)
      end

      assert fresh(first).protected_dispatch_fee == 0
    end
  end

  defp standard_splits(store, payment, supplier) do
    [
      create_split!(store, payment, %{role: :wholesaler, supplier_id: supplier.id, amount: 6_000}),
      create_split!(store, payment, %{role: :dropshipper, amount: 3_000}),
      create_split!(store, payment, %{role: :platform, amount: 1_000})
    ]
  end

  defp reversals(splits), do: Enum.map(splits, &fresh(&1).reversed_amount)

  # Production re-reads the splits on every refund webhook — `reverse_splits/1`
  # calls `payment_splits/1` first. A sequential-refund test that reuses the
  # in-memory structs carries a stale `reversed_amount` of 0 into the next
  # call, which hides exactly the staleness bugs the real caller would hit.
  defp reread(splits), do: Enum.map(splits, &fresh/1)

  defp approve_return!(store, order, attrs) do
    Emakola.Orders.Return
    |> Ash.Changeset.for_create(:request_return, %{
      store_id: store.id,
      order_id: order.id,
      reason: :changed_mind
    })
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:approve, Map.new(attrs))
    |> Ash.update!(authorize?: false)
  end

  defp create_split!(store, payment, attrs) do
    attrs
    |> Map.merge(%{store_id: store.id, payment_id: payment.id})
    |> then(&Emakola.Payments.create_payment_split!(&1, authorize?: false))
  end

  defp fresh(split), do: Ash.get!(PaymentSplit, split.id, authorize?: false)

  describe "outstanding_for_recipient!/1" do
    test "sums outstanding over the recipient's recoverable splits, floored at zero" do
      store = create_store!(name: "Owing Store")
      payment = create_payment!(store)

      # A claimed internal split reversed AFTER its claim: frozen fence 0,
      # reversal 3_000 → outstanding 3_000.
      _owing =
        split_fixture!(payment, store,
          amount: 10_000,
          settlement_method: :internal_hold,
          status: :partially_reversed,
          reversed_amount: 3_000,
          paid_out_at: DateTime.utc_now(),
          netted_reversal_amount: 0
        )

      # An UNCLAIMED internal split with a reversal nets at source:
      # effective_netted = min(amount, reversed) → outstanding 0.
      _self_netting =
        split_fixture!(payment, store,
          amount: 5_000,
          settlement_method: :internal_hold,
          status: :partially_reversed,
          reversed_amount: 2_000
        )

      {:ok, {splits, total}} =
        Emakola.Repo.transaction(fn ->
          Emakola.Payments.RefundLiability.outstanding_for_recipient!(store.id)
        end)

      assert total == 3_000
      # `_self_netting` nets to 0 at source and never passes
      # `recoverable_by_recipient`'s filter — `_owing` is the only row it can
      # return for this store, so this is exactly one element, not "at least".
      assert [_] = splits
    end

    test "a recipient with no liabilities owes zero" do
      store = create_store!(name: "Clean Store")

      {:ok, {splits, total}} =
        Emakola.Repo.transaction(fn ->
          Emakola.Payments.RefundLiability.outstanding_for_recipient!(store.id)
        end)

      assert splits == []
      assert total == 0
    end
  end

  # Drives a PaymentSplit through its real lifecycle actions to the target
  # state instead of force-writing claim-lifecycle attrs — :create rejects
  # paid_out_at/netted_reversal_amount (see PaymentSplit's :create accept
  # list). `paid_out_at` present means the claim happens BEFORE the reversal
  # (mirrors refund_liability_no_double_claw_test.exs's settled_internal!/
  # mark_paid_out idiom); its exact value is irrelevant, only presence.
  #
  # supplier_id gets a fresh UUID per call purely to dodge unique_allocation
  # (payment_id, role, supplier_id, credit_agreement_id): both fixtures below
  # share one payment_id and role: :merchant, and the identity treats nulls
  # as equal, so two nil supplier_ids on the same payment would collide.
  defp split_fixture!(payment, store, opts) do
    opts = Map.new(opts)

    split =
      PaymentSplit
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        supplier_id: Ash.UUID.generate(),
        amount: Map.fetch!(opts, :amount),
        settlement_method: Map.get(opts, :settlement_method, :gateway_share)
      })
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)

    split =
      if Map.has_key?(opts, :paid_out_at) do
        split
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
        |> Ash.update!(authorize?: false)
      else
        split
      end

    case Map.get(opts, :reversed_amount) do
      nil ->
        split

      reversed_amount ->
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
        |> Ash.update!(authorize?: false)
    end
  end
end
