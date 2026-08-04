defmodule Emakola.Customers.ActionImplementationBoundaryTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  describe "find_or_create implementation boundary" do
    test "keeps same-email customers isolated by the owning resource's store" do
      local_store = create_store!(name: "Local Customer Store")
      foreign_store = create_store!(name: "Foreign Customer Store")
      foreign = create_customer!(foreign_store, email: "shared@example.com")

      local =
        Emakola.Customers.Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: "shared@example.com",
          store_id: local_store.id,
          name: "Local Customer"
        })
        |> Ash.run_action!()

      assert local.store_id == local_store.id
      assert local.id != foreign.id
      assert to_string(local.email) == to_string(foreign.email)
    end
  end

  describe "set_default implementation boundary" do
    test "keeps the customer actor ownership check across stores" do
      local_store = create_store!(name: "Local Address Store")
      local_customer = create_customer!(local_store, email: "local-address@example.com")
      local_address = create_address!(local_customer, local_store, line_1: "Local", city: "Accra")

      foreign_store = create_store!(name: "Foreign Address Store")
      foreign_customer = create_customer!(foreign_store, email: "foreign-address@example.com")

      assert {:error, %Ash.Error.Forbidden{}} =
               Emakola.Customers.Address
               |> Ash.ActionInput.for_action(:set_as_default, %{address_id: local_address.id},
                 actor: foreign_customer
               )
               |> Ash.run_action()

      refute Ash.reload!(local_address, authorize?: false).is_default
    end

    test "rejects an actor-shaped map that is not a Customer resource" do
      store = create_store!(name: "Impostor Actor Store")
      customer = create_customer!(store, email: "real-customer@example.com")
      address = create_address!(customer, store, line_1: "Guarded", city: "Accra")
      impostor = %{id: customer.id, store_id: store.id}

      assert {:error, %Ash.Error.Forbidden{}} =
               Emakola.Customers.Address
               |> Ash.ActionInput.for_action(:set_as_default, %{address_id: address.id},
                 actor: impostor
               )
               |> Ash.run_action()

      refute Ash.reload!(address, authorize?: false).is_default
    end
  end
end
