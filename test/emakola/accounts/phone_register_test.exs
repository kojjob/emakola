defmodule Emakola.Accounts.PhoneRegisterTest do
  use Emakola.DataCase, async: true

  test "merchant register_with_phone creates a passwordless, confirmed merchant" do
    {:ok, m} =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_phone, %{
        email: "wa-merchant@example.com",
        name: "Akua",
        phone: "+233501234567"
      })
      |> Ash.create(authorize?: false)

    assert m.phone == "+233501234567"
    assert is_nil(m.hashed_password)
    refute is_nil(m.confirmed_at)
  end

  test "customer register_with_phone creates a store-scoped customer" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    {:ok, c} =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(
        :register_with_phone,
        %{email: "wa-cust@example.com", name: "Kofi", phone: "+233502223333"},
        tenant: store.id
      )
      |> Ash.create(authorize?: false)

    assert c.store_id == store.id
    assert c.phone == "+233502223333"
  end

  describe "phone_verified_at" do
    test "registering by phone stamps the number as proven" do
      {:ok, merchant} =
        Emakola.Accounts.Merchant
        |> Ash.Changeset.for_create(:register_with_phone, %{
          email: "proof#{System.unique_integer([:positive])}@example.com",
          name: "Ama",
          phone: "+233244000010"
        })
        |> Ash.create(authorize?: false)

      assert %DateTime{} = merchant.phone_verified_at
    end

    test "changing the phone drops the proof" do
      {:ok, merchant} =
        Emakola.Accounts.Merchant
        |> Ash.Changeset.for_create(:register_with_phone, %{
          email: "proof#{System.unique_integer([:positive])}@example.com",
          name: "Ama",
          phone: "+233244000011"
        })
        |> Ash.create(authorize?: false)

      {:ok, updated} =
        merchant
        |> Ash.Changeset.for_update(:update_profile, %{phone: "+233244000012"})
        |> Ash.update(authorize?: false)

      assert is_nil(updated.phone_verified_at),
             "an unanswered number must not inherit the old number's proof"
    end

    test "editing an unrelated field keeps the proof" do
      {:ok, merchant} =
        Emakola.Accounts.Merchant
        |> Ash.Changeset.for_create(:register_with_phone, %{
          email: "proof#{System.unique_integer([:positive])}@example.com",
          name: "Ama",
          phone: "+233244000013"
        })
        |> Ash.create(authorize?: false)

      {:ok, updated} =
        merchant
        |> Ash.Changeset.for_update(:update_profile, %{name: "Ama Trades"})
        |> Ash.update(authorize?: false)

      assert %DateTime{} = updated.phone_verified_at
    end
  end
end
