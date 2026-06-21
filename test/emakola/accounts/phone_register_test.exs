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
end
