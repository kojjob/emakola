defmodule Emakola.Customers.SegmentsTest do
  @moduledoc """
  Segments are computed from order history, nothing new is tracked. They let
  a merchant send a paid SMS to the people it is for.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import ExUnit.CaptureLog

  alias Emakola.Customers.Segments

  setup do
    {:ok, store: create_store!()}
  end

  defp customer_with_orders!(store, name, orders) do
    customer =
      create_customer!(store, %{
        name: name,
        phone:
          "+23324#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"
      })

    for {total, status, days_ago} <- orders do
      order =
        create_order!(store, %{
          subtotal: total,
          total: total,
          status: status,
          customer_id: customer.id
        })

      backdate_order!(order, days_ago)
    end

    last = orders |> Enum.map(&elem(&1, 2)) |> Enum.min(fn -> nil end)

    if last do
      customer
      |> Ash.Changeset.for_update(:backdate_last_order, %{
        last_order_at: DateTime.add(DateTime.utc_now(), -last * 86_400, :second)
      })
      |> Ash.update!(authorize?: false)
    else
      customer
    end
  end

  # inserted_at is not writable through Ash; set it directly for history.
  defp backdate_order!(order, days_ago) do
    at = DateTime.add(DateTime.utc_now(), -days_ago * 86_400, :second)

    Emakola.Repo.query!("update orders set inserted_at = $1 where id = $2", [
      at,
      Ecto.UUID.dump!(order.id)
    ])

    order
  end

  defp ids(query), do: query |> Ash.read!(authorize?: false) |> Enum.map(& &1.id) |> Enum.sort()

  test "new: first paid order within 30 days", %{store: store} do
    new = customer_with_orders!(store, "New", [{1_000, :confirmed, 3}])
    _old = customer_with_orders!(store, "Old", [{1_000, :confirmed, 90}])
    _unpaid = customer_with_orders!(store, "Unpaid", [{1_000, :pending, 1}])

    assert ids(Segments.query(store.id, :new)) == [new.id]
  end

  test "bought again: two or more paid orders", %{store: store} do
    twice =
      customer_with_orders!(store, "Twice", [{1_000, :confirmed, 3}, {1_000, :delivered, 40}])

    _once = customer_with_orders!(store, "Once", [{1_000, :confirmed, 3}])

    assert ids(Segments.query(store.id, :bought_again)) == [twice.id]
  end

  test "gone quiet: last PAID order over 60 days ago, even with a recent unpaid touch",
       %{store: store} do
    # The pending order is more recent than the paid one, so last_order_at
    # (touched by CheckoutService on every checkout, paid or not) reads as
    # recent. gone_quiet must not be fooled by it — only last_paid_order_at
    # counts.
    quiet = customer_with_orders!(store, "Quiet", [{1_000, :confirmed, 75}, {1_000, :pending, 1}])
    _active = customer_with_orders!(store, "Active", [{1_000, :confirmed, 5}])
    _never = create_customer!(store, %{name: "Never"})

    assert ids(Segments.query(store.id, :gone_quiet)) == [quiet.id]
  end

  test "big spenders: the top fifth by paid money, once five people have bought", %{store: store} do
    spenders =
      for {name, total} <- [{"A", 50_000}, {"B", 9_000}, {"C", 8_000}, {"D", 7_000}, {"E", 6_000}] do
        customer_with_orders!(store, name, [{total, :confirmed, 2}])
      end

    [a | _] = spenders
    assert ids(Segments.query(store.id, :big_spenders)) == [a.id]
  end

  test "big spenders is empty under five buyers", %{store: store} do
    customer_with_orders!(store, "A", [{50_000, :confirmed, 2}])

    assert ids(Segments.query(store.id, :big_spenders)) == []
  end

  test "big spenders: the top fifth with ten buyers (keep = 2, not the n = 5 edge case)", %{
    store: store
  } do
    totals = [50_000, 40_000, 30_000, 20_000, 15_000, 10_000, 9_000, 8_000, 7_000, 6_000]

    buyers =
      for {total, i} <- Enum.with_index(totals) do
        customer_with_orders!(store, "Buyer#{i}", [{total, :confirmed, 2}])
      end

    top_two_ids = buyers |> Enum.take(2) |> Enum.map(& &1.id) |> Enum.sort()

    assert ids(Segments.query(store.id, :big_spenders)) == top_two_ids
  end

  test "counts cover every segment and never cross stores", %{store: store} do
    customer_with_orders!(store, "New", [{1_000, :confirmed, 3}])
    other = create_store!()
    customer_with_orders!(other, "Theirs", [{1_000, :confirmed, 3}])

    assert %{everyone: 1, new: 1, bought_again: 0, big_spenders: 0, gone_quiet: 0} =
             Segments.counts(store.id)
  end

  test "an unknown segment atom logs and returns empty, never everyone", %{store: store} do
    customer_with_orders!(store, "Someone", [{1_000, :confirmed, 3}])

    log =
      capture_log(fn ->
        assert ids(Segments.query(store.id, :not_a_real_segment)) == []
      end)

    assert log =~ "unknown segment"
  end
end
