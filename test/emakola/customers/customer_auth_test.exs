defmodule Emakola.Customers.CustomerAuthTest do
  use Emakola.DataCase, async: false
  require Ash.Query
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
        |> Ash.create!(authorize?: false)

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
        |> Ash.create!(authorize?: false)
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
        |> Ash.create!(authorize?: false)
      end
    end

    test "rejects a phone-placeholder email", %{store: store} do
      # p233241234567@phone.customers.makola.io is what
      # CheckoutService.phone_placeholder_email("+233241234567") generates.
      # A public registration that claims it could later be handed back as
      # the "credential-less" fallback customer for a guest checking out
      # with that phone — see NotPlaceholderEmail and
      # FindOrCreateCustomer.fallback_to_credential_less/4.
      assert {:error, error} =
               Emakola.Customers.Customer
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "p233241234567@phone.customers.makola.io",
                 password: "Password123!",
                 password_confirmation: "Password123!",
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)

      assert Exception.message(error) =~ "Use your own email address"

      refute Emakola.Customers.Customer
             |> Ash.Query.filter(store_id == ^store.id)
             |> Ash.exists?(authorize?: false)
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
        |> Ash.create!(authorize?: false)

      c2 =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "multi@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store2.id
        })
        |> Ash.create!(authorize?: false)

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
        |> Ash.create!(authorize?: false)

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
        |> Ash.create!(authorize?: false)

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
