defmodule Emakola.Payments.ProtectionHoldTest do
  use Emakola.DataCase, async: true

  alias Emakola.Payments.ProtectionHold

  defp create!(store, payment, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      payment_id: payment.id,
      order_id: payment.order_id,
      amount: 25_000,
      fee: 1_000,
      net: 24_000
    }

    ProtectionHold
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create(store, payment, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      payment_id: payment.id,
      order_id: payment.order_id,
      amount: 25_000,
      fee: 1_000,
      net: 24_000
    }

    ProtectionHold
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create(authorize?: false)
  end

  # ── Invariant: fee + net == amount ────────────────────────────────

  test "create rejects a fee/net snapshot that does not sum to amount" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})

    assert {:error, %Ash.Error.Invalid{}} =
             create(store, payment, %{amount: 25_000, fee: 1_000, net: 20_000})
  end

  test "create succeeds when fee + net == amount, defaulting to :held" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})

    hold = create!(store, payment)

    assert hold.status == :held
    assert hold.amount == 25_000
    assert hold.fee == 1_000
    assert hold.net == 24_000
    assert hold.payment_id == payment.id
    assert hold.order_id == order.id
  end

  # ── Unique payment_id (idempotent hold creation) ──────────────────

  test "a second create for the same payment_id errors" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})

    _first = create!(store, payment)

    assert {:error, %Ash.Error.Invalid{}} = create(store, payment)
  end

  # ── State machine: release only from :held ────────────────────────

  test "release transitions a held hold to :released, stamping released_at and release_reason" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    released =
      hold
      |> Ash.Changeset.for_update(:release, %{release_reason: :buyer_confirmed})
      |> Ash.update!(authorize?: false)

    assert released.status == :released
    assert released.release_reason == :buyer_confirmed
    assert %DateTime{} = released.released_at
  end

  test "release rejects a hold that is already released" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    released =
      hold
      |> Ash.Changeset.for_update(:release, %{release_reason: :buyer_confirmed})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             released
             |> Ash.Changeset.for_update(:release, %{release_reason: :staff})
             |> Ash.update(authorize?: false)
  end

  test "release rejects a hold that is already refunded" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    refunded =
      hold
      |> Ash.Changeset.for_update(:mark_refunded, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             refunded
             |> Ash.Changeset.for_update(:release, %{release_reason: :staff})
             |> Ash.update(authorize?: false)
  end

  # ── State machine: refund only from :held ─────────────────────────

  test "mark_refunded transitions a held hold to :refunded" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    refunded =
      hold
      |> Ash.Changeset.for_update(:mark_refunded, %{resolution: :merchant_refunded})
      |> Ash.update!(authorize?: false)

    assert refunded.status == :refunded
    assert refunded.resolution == :merchant_refunded
  end

  test "mark_refunded rejects a hold that is already released" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    released =
      hold
      |> Ash.Changeset.for_update(:release, %{release_reason: :buyer_confirmed})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             released
             |> Ash.Changeset.for_update(:mark_refunded, %{})
             |> Ash.update(authorize?: false)
  end

  # ── Complaint freeze: blocks nothing structurally but sets frozen_at ─

  test "freeze sets frozen_at while leaving status :held" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    frozen =
      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

    assert frozen.status == :held
    assert %DateTime{} = frozen.frozen_at
    assert frozen.complaint_reason == :not_received
    assert frozen.complaint_text == "Never arrived"
  end

  test "release and mark_refunded remain reachable on a frozen (still :held) hold" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    frozen =
      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

    released =
      frozen
      |> Ash.Changeset.for_update(:release, %{release_reason: :staff})
      |> Ash.update!(authorize?: false)

    assert released.status == :released
  end

  # ── Double-freeze routes to update_complaint ───────────────────────

  test "freeze on an already-frozen hold errors" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    frozen =
      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             frozen
             |> Ash.Changeset.for_update(:freeze, %{
               complaint_reason: :other,
               complaint_text: "Still nothing"
             })
             |> Ash.update(authorize?: false)
  end

  test "update_complaint updates text (+reason) on an already-frozen hold" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    frozen =
      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

    updated =
      frozen
      |> Ash.Changeset.for_update(:update_complaint, %{
        complaint_reason: :other,
        complaint_text: "Actually it arrived broken"
      })
      |> Ash.update!(authorize?: false)

    assert updated.status == :held
    assert updated.frozen_at == frozen.frozen_at
    assert updated.complaint_reason == :other
    assert updated.complaint_text == "Actually it arrived broken"
  end

  test "update_complaint rejects a hold that has never been frozen" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    assert {:error, %Ash.Error.Invalid{}} =
             hold
             |> Ash.Changeset.for_update(:update_complaint, %{
               complaint_reason: :other,
               complaint_text: "Still nothing"
             })
             |> Ash.update(authorize?: false)
  end

  # ── unfreeze ────────────────────────────────────────────────────────

  test "unfreeze clears frozen_at" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    frozen =
      hold
      |> Ash.Changeset.for_update(:freeze, %{
        complaint_reason: :not_received,
        complaint_text: "Never arrived"
      })
      |> Ash.update!(authorize?: false)

    unfrozen =
      frozen
      |> Ash.Changeset.for_update(:unfreeze, %{})
      |> Ash.update!(authorize?: false)

    assert unfrozen.frozen_at == nil
  end

  # ── set_release_after ────────────────────────────────────────────────

  test "set_release_after sets the release timer while :held" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    release_after = DateTime.add(DateTime.utc_now(), 5, :day)

    updated =
      hold
      |> Ash.Changeset.for_update(:set_release_after, %{release_after: release_after})
      |> Ash.update!(authorize?: false)

    assert DateTime.diff(updated.release_after, release_after) == 0
  end

  test "set_release_after rejects a hold that is not :held" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    released =
      hold
      |> Ash.Changeset.for_update(:release, %{release_reason: :staff})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             released
             |> Ash.Changeset.for_update(:set_release_after, %{
               release_after: DateTime.utc_now()
             })
             |> Ash.update(authorize?: false)
  end

  # ── get_by_payment / tenant isolation ─────────────────────────────

  test "get_by_payment finds the hold for its own tenant" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
    hold = create!(store, payment)

    assert {:ok, found} =
             ProtectionHold
             |> Ash.Query.for_read(:get_by_payment, %{payment_id: payment.id})
             |> Ash.Query.set_tenant(store.id)
             |> Ash.read_one(authorize?: false)

    assert found.id == hold.id
  end

  test "tenant isolation: store B cannot read store A's hold via get_by_payment" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store_a)
    payment = Emakola.Factory.create_payment!(store_a, %{order_id: order.id})
    _hold = create!(store_a, payment)

    assert {:ok, nil} =
             ProtectionHold
             |> Ash.Query.for_read(:get_by_payment, %{payment_id: payment.id})
             |> Ash.Query.set_tenant(store_b.id)
             |> Ash.read_one(authorize?: false)
  end

  test "domain code interfaces exist and work end to end" do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})

    {:ok, hold} =
      Emakola.Payments.create_protection_hold(
        %{
          store_id: store.id,
          payment_id: payment.id,
          order_id: order.id,
          amount: 25_000,
          fee: 1_000,
          net: 24_000
        },
        tenant: store.id,
        authorize?: false
      )

    assert hold.status == :held

    {:ok, released} =
      Emakola.Payments.release_protection_hold(hold, %{release_reason: :auto_timer},
        authorize?: false
      )

    assert released.status == :released

    {:ok, found} =
      Emakola.Payments.get_protection_hold_by_payment(payment.id,
        tenant: store.id,
        authorize?: false
      )

    assert found.id == hold.id
  end
end
