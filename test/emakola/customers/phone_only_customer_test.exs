defmodule Emakola.Customers.PhoneOnlyCustomerTest do
  @moduledoc """
  A buyer must be able to exist with a phone and no email.

  Until now `Customer.email` was `allow_nil?(false)`, so the WhatsApp signup
  still had to ask for an email address — phone-first signup was impossible
  in a market where most buyers do not use email at all.

  The replacement rule is not "anything goes": a customer must be reachable
  by **something**, or the shop can never tell them their order shipped.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Customers.Customer
  alias Emakola.Notifications.Reach

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  test "registers with a phone and no email", %{store: store} do
    assert {:ok, customer} =
             Customer
             |> Ash.Changeset.for_create(
               :register_with_phone,
               %{name: "Ama", phone: "+233201234567"},
               tenant: store.id
             )
             |> Ash.create(authorize?: false)

    assert is_nil(customer.email)
    assert to_string(customer.phone) == "+233201234567"

    # The whole point: this customer is reachable.
    assert Reach.channels_for(customer, :transactional) == [:whatsapp, :sms]
  end

  test "refuses a customer with neither phone nor email", %{store: store} do
    assert {:error, error} =
             Customer
             |> Ash.Changeset.for_create(:register_with_phone, %{name: "Nobody"},
               tenant: store.id
             )
             |> Ash.create(authorize?: false)

    assert Exception.message(error) =~ "phone"
  end

  test "still registers with an email and no phone", %{store: store} do
    assert {:ok, customer} =
             Customer
             |> Ash.Changeset.for_create(
               :create,
               %{name: "Kofi", email: "kofi@example.com", store_id: store.id}
             )
             |> Ash.create(authorize?: false)

    assert is_nil(customer.phone)
    assert Reach.channels_for(customer, :transactional) == [:email]
  end

  test "two phone-only customers do not collide on a null email", %{store: store} do
    # Postgres treats NULLs as distinct in a unique index, but this is the
    # exact shape that breaks if someone "fixes" the identity with a default
    # empty string instead of nil.
    for phone <- ["+233201111111", "+233202222222"] do
      assert {:ok, _} =
               Customer
               |> Ash.Changeset.for_create(:register_with_phone, %{phone: phone},
                 tenant: store.id
               )
               |> Ash.create(authorize?: false)
    end
  end
end
