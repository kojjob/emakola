defmodule Emakola.Suppliers.CommercePassportsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Ecto.Query

  alias Emakola.Suppliers.CommercePassports

  test "builds a bounded passport from aggregate evidence and supports repeat refresh" do
    {actor, store} = create_merchant_with_store!()
    delivered_a = create_order!(store)
    delivered_b = create_order!(store)
    cancelled = create_order!(store)

    Enum.each([delivered_a.id, delivered_b.id], fn order_id ->
      Emakola.Repo.update_all(
        from(o in "orders", where: o.id == type(^order_id, Ecto.UUID)),
        set: [status: "delivered"]
      )
    end)

    Emakola.Repo.update_all(
      from(o in "orders", where: o.id == type(^cancelled.id, Ecto.UUID)),
      set: [status: "cancelled"]
    )

    successful = create_payment!(store, amount: 10_000)
    successful |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    refunded = create_payment!(store, amount: 5_000)

    refunded =
      refunded |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    refunded
    |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: refunded.amount})
    |> Ash.update!(authorize?: false)

    assert {:ok, passport} = CommercePassports.refresh(actor, store.id)
    assert passport.score in 0..1_000
    assert passport.tier == :starter
    assert passport.metrics["fulfilled_orders"] == 2
    assert passport.metrics["cancelled_orders"] == 1
    assert passport.metrics["refunded_payments"] == 1
    assert length(passport.signals) == 4
    assert Enum.all?(passport.signals, &(&1.reason_code && &1.evidence != %{}))
    assert Enum.all?(passport.signals, &(DateTime.compare(&1.expires_at, &1.observed_at) == :gt))
    refute Enum.any?(passport.signals, &Map.has_key?(&1.evidence, "customer_id"))

    assert {:ok, refreshed} = CommercePassports.refresh(actor, store.id)
    assert refreshed.id == passport.id
    assert length(Enum.filter(refreshed.signals, &(&1.status == :active))) == 4
    assert length(Enum.filter(refreshed.signals, &(&1.status == :expired))) == 4
  end

  test "merchant can appeal a signal and a correction preserves reasoned audit state" do
    {actor, store} = create_merchant_with_store!()
    {:ok, passport} = CommercePassports.refresh(actor, store.id)
    signal = Enum.find(passport.signals, &(&1.kind == :service_quality))

    assert {:error, :invalid_appeal} =
             CommercePassports.appeal(actor, store.id, signal.id, "short")

    assert {:ok, appeal} =
             CommercePassports.appeal(
               actor,
               store.id,
               signal.id,
               "A delivered order is missing from this calculation."
             )

    assert appeal.status == :open

    assert Ash.get!(Emakola.Suppliers.ReputationSignal, signal.id, authorize?: false).status ==
             :appealed

    assert {:ok, corrected} =
             CommercePassports.correct_signal(signal.id, appeal.id, %{
               value: 10_000,
               impact: 200,
               evidence: %{"delivered" => 1, "cancelled" => 0},
               reason: "Verified delivery evidence was added."
             })

    assert corrected.status == :corrected
    assert corrected.correction_reason == "Verified delivery evidence was added."
    assert corrected.corrected_at

    resolved = Ash.get!(Emakola.Suppliers.ReputationAppeal, appeal.id, authorize?: false)
    assert resolved.status == :upheld
    assert resolved.resolved_at
  end

  test "passport inspection and appeals are store-authorized" do
    {actor, store} = create_merchant_with_store!()
    {stranger, stranger_store} = create_merchant_with_store!()
    {:ok, passport} = CommercePassports.refresh(actor, store.id)
    signal = List.first(passport.signals)

    assert {:error, :forbidden} = CommercePassports.inspect(stranger, store.id)

    assert {:error, :forbidden} =
             CommercePassports.appeal(
               stranger,
               store.id,
               signal.id,
               "This should not be allowed."
             )

    assert {:ok, _own} = CommercePassports.inspect(stranger, stranger_store.id)
  end
end
