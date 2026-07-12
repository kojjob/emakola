defmodule Emakola.Payments.Workers.PaymentExpiryWorkerTest do
  @moduledoc """
  Post-merge hardening (2026-07-11 review): an abandoned checkout left its
  refund-liability recovery reservation held forever, permanently blocking
  debt recovery from the merchant's future earnings. Stale pending payments
  must be failed and their reservations released.
  """

  use Emakola.DataCase, async: true

  import Ecto.Query
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Payments.{PaymentSplit, RefundLiability}
  alias Emakola.Payments.Workers.PaymentExpiryWorker

  setup do
    seller = create_store!(name: "Indebted seller")
    original_store = create_store!(name: "Original checkout store")
    original_payment = create_payment!(original_store)

    liability =
      Emakola.Payments.create_payment_split!(
        %{
          store_id: original_store.id,
          payment_id: original_payment.id,
          role: :wholesaler,
          recipient_store_id: seller.id,
          amount: 1_000
        },
        authorize?: false
      )
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 700})
      |> Ash.update!(authorize?: false)

    {:ok, seller: seller, liability: liability}
  end

  test "fails stale pending payments and releases their recovery reservations", ctx do
    {payment, _splits} = reserved_checkout!(ctx.seller, 500)
    assert fresh(ctx.liability).reserved_recovery_amount == 500

    force_age!(payment.id, hours: 25)

    assert :ok = PaymentExpiryWorker.perform(%Oban.Job{})

    assert fresh(ctx.liability).reserved_recovery_amount == 0
    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :failed
  end

  test "leaves fresh pending payments and their reservations alone", ctx do
    {payment, _splits} = reserved_checkout!(ctx.seller, 500)

    assert :ok = PaymentExpiryWorker.perform(%Oban.Job{})

    assert fresh(ctx.liability).reserved_recovery_amount == 500
    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :pending
  end

  test "a second run is a no-op — no double release", ctx do
    {payment, _splits} = reserved_checkout!(ctx.seller, 500)
    force_age!(payment.id, hours: 25)

    assert :ok = PaymentExpiryWorker.perform(%Oban.Job{})
    assert :ok = PaymentExpiryWorker.perform(%Oban.Job{})

    assert fresh(ctx.liability).reserved_recovery_amount == 0
  end

  test "successful payments are never expired", ctx do
    {payment, _splits} = reserved_checkout!(ctx.seller, 500)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    force_age!(payment.id, hours: 25)

    assert :ok = PaymentExpiryWorker.perform(%Oban.Job{})

    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :success
    assert fresh(ctx.liability).reserved_recovery_amount == 500
  end

  # Reserve debt against a new checkout and persist its splits, exactly like
  # OrderSettlement.prepare/record_splits! does at payment initiation.
  defp reserved_checkout!(seller, earning) do
    allocations =
      RefundLiability.reserve!([
        %{
          role: :merchant,
          recipient_store_id: seller.id,
          subaccount_code: "ACCT_seller",
          amount: earning
        },
        %{role: :platform, recipient_store_id: nil, subaccount_code: nil, amount: 100}
      ])

    payment = create_payment!(seller, amount: earning + 100)
    :ok = Emakola.Payments.OrderSettlement.record_splits!(payment, allocations)

    splits =
      PaymentSplit
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    {payment, splits}
  end

  defp force_age!(payment_id, hours: hours) do
    past = DateTime.add(DateTime.utc_now(), -hours, :hour)

    Emakola.Repo.update_all(
      from(p in "payments", where: p.id == type(^payment_id, Ecto.UUID)),
      set: [inserted_at: past]
    )
  end

  defp fresh(split), do: Ash.get!(PaymentSplit, split.id, authorize?: false)
end
