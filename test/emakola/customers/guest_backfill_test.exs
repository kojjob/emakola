defmodule Emakola.Customers.GuestBackfillTest do
  @moduledoc """
  Storefront checkout created every guest order with no customer. The backfill
  links those orders by the phone in the shipping address, once, and never
  invents a person for an order that carries no phone.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Customers.{Customer, GuestBackfill}
  alias Emakola.Orders.Order

  setup do
    {:ok, store: create_store!()}
  end

  defp guest_order!(store, phone, name, opts \\ []) do
    create_order!(
      store,
      Map.merge(
        %{
          subtotal: 5_000,
          total: 5_000,
          shipping_address: %{
            "name" => name,
            "phone" => phone,
            "address" => "Osu",
            "region" => "greater_accra"
          }
        },
        Map.new(opts)
      )
    )
  end

  defp reload_order(order), do: Ash.get!(Order, order.id, authorize?: false)

  test "two guest orders from one phone become one customer with both orders", %{store: store} do
    a = guest_order!(store, "+233241234567", "Ama Serwaa")
    b = guest_order!(store, "0241234567", "Ama")

    assert %{linked: 2, skipped: 0} = GuestBackfill.run()

    a = reload_order(a)
    b = reload_order(b)
    assert a.customer_id
    assert a.customer_id == b.customer_id

    customer = Ash.get!(Customer, a.customer_id, authorize?: false)
    assert customer.phone == "+233241234567"
    assert customer.name == "Ama Serwaa"
    assert customer.store_id == store.id
  end

  test "last bought is the newest order's date, not now", %{store: store} do
    order = guest_order!(store, "+233241234567", "Ama")

    GuestBackfill.run()

    customer = Ash.get!(Customer, reload_order(order).customer_id, authorize?: false)
    assert DateTime.compare(customer.last_order_at, order.inserted_at) == :eq
  end

  test "an order with no phone is left alone", %{store: store} do
    order =
      create_order!(store, %{subtotal: 100, total: 100, shipping_address: %{"address" => "x"}})

    assert %{linked: 0, skipped: 1} = GuestBackfill.run()
    refute reload_order(order).customer_id
  end

  test "a second run changes nothing", %{store: store} do
    guest_order!(store, "+233241234567", "Ama")

    assert %{linked: 1} = GuestBackfill.run()
    assert %{linked: 0, skipped: 0} = GuestBackfill.run()
    assert Customer |> Ash.count!(authorize?: false) == 1
  end

  test "a dry run counts and writes nothing", %{store: store} do
    order = guest_order!(store, "+233241234567", "Ama")

    assert %{linked: 1} = GuestBackfill.run(dry_run?: true)
    refute reload_order(order).customer_id
  end
end
