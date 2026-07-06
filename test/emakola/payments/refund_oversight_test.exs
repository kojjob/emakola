defmodule Emakola.Payments.RefundOversightTest do
  @moduledoc """
  Platform refund oversight: the cross-store `:list_refunded` read and the
  total_refunded / refund_count aggregates (over existing Payment data).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Platform.Stats

  defp refunded!(store, amount) do
    payment = Factory.create_payment!(store, %{amount: amount})

    {:ok, payment} =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update(authorize?: false)

    {:ok, payment} =
      payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: amount})
      |> Ash.update(authorize?: false)

    payment
  end

  test "list_refunded_payments returns refunded payments across stores, loaded with store" do
    s1 = Factory.create_store!()
    s2 = Factory.create_store!()
    refunded!(s1, 100_000)
    refunded!(s2, 50_000)
    # a non-refunded payment must be excluded
    Factory.create_payment!(s1)

    {:ok, list} = Payments.list_refunded_payments(authorize?: false)

    assert length(list) == 2
    assert Enum.all?(list, &(&1.status == :refunded))
    assert Enum.all?(list, &is_struct(&1.store))
  end

  test "total_refunded sums refunded_amount and refund_count counts refunds" do
    s = Factory.create_store!()
    refunded!(s, 100_000)
    refunded!(s, 50_000)
    Factory.create_payment!(s)

    assert Stats.total_refunded() == 150_000
    assert Stats.refund_count() == 2
  end
end
