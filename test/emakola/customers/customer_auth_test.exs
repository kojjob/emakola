defmodule Emakola.Customers.CustomerAuthTest do
  use Emakola.DataCase, async: false
  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    %{store: store}
  end

  describe "customer registration with password" do
    test "creates customer with email and password", %{store: store} do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "shopper@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id
        })
        |> Ash.create!()

      assert to_string(customer.email) == "shopper@example.com"
      assert customer.store_id == store.id
      assert customer.hashed_password != nil
    end

    test "rejects mismatched password confirmation", %{store: store} do
      assert_raise Ash.Error.Invalid, fn ->
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "shopper@example.com",
          password: "Password123!",
          password_confirmation: "DifferentPassword!",
          store_id: store.id
        })
        |> Ash.create!()
      end
    end

    test "rejects password shorter than 8 characters", %{store: store} do
      assert_raise Ash.Error.Invalid, fn ->
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "shopper@example.com",
          password: "short",
          password_confirmation: "short",
          store_id: store.id
        })
        |> Ash.create!()
      end
    end

    test "same email in different stores succeeds", %{store: store} do
      {_m, store2} = Factory.create_merchant_with_store!()

      c1 =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "multi@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id
        })
        |> Ash.create!()

      c2 =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "multi@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store2.id
        })
        |> Ash.create!()

      assert c1.store_id == store.id
      assert c2.store_id == store2.id
      assert c1.id != c2.id
    end

    test "generates authentication token on registration", %{store: store} do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "tokentest@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id
        })
        |> Ash.create!()

      assert customer.__metadata__[:token] != nil
    end

    test "accepts optional name and phone", %{store: store} do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "named@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id,
          name: "Kwame Asante",
          phone: "+233201234567"
        })
        |> Ash.create!()

      assert customer.name == "Kwame Asante"
      assert customer.phone == "+233201234567"
    end
  end

  describe "backward compatibility" do
    test "existing create action still works without password", %{store: store} do
      customer = Factory.create_customer!(store)
      assert customer.hashed_password == nil
      assert customer.email != nil
    end

    test "find_or_create action still works", %{store: store} do
      {:ok, customer} =
        Emakola.Customers.find_or_create_customer(
          "checkout@example.com",
          store.id,
          %{name: "Checkout Buyer"}
        )

      assert to_string(customer.email) == "checkout@example.com"
      assert customer.hashed_password == nil
    end
  end
end
