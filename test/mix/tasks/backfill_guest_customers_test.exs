defmodule Mix.Tasks.Emakola.BackfillGuestCustomersTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  test "links guest orders and reports the counts" do
    store = create_store!()

    create_order!(store, %{
      subtotal: 100,
      total: 100,
      shipping_address: %{"name" => "Ama", "phone" => "+233241234567"}
    })

    Mix.Tasks.Emakola.BackfillGuestCustomers.run([])

    assert Emakola.Customers.Customer |> Ash.count!(authorize?: false) == 1
  end

  test "the release entry point returns the same counts" do
    store = create_store!()

    create_order!(store, %{
      subtotal: 100,
      total: 100,
      shipping_address: %{"name" => "Ama", "phone" => "+233241234567"}
    })

    assert %{linked: 1, skipped: 0} = Emakola.Release.backfill_guest_customers(true)
  end
end
