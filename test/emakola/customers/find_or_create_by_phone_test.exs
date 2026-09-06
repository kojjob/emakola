defmodule Emakola.Customers.FindOrCreateByPhoneTest do
  @moduledoc """
  A phone-first market keys the customer on the phone. Two checkouts from the
  same number, one with an email and one without, must be one person.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Customers.Customer
  alias Emakola.Orders.CheckoutService

  setup do
    {:ok, store: create_store!()}
  end

  defp find_or_create!(store, attrs) do
    Customer
    |> Ash.ActionInput.for_action(:find_or_create, Map.put(attrs, :store_id, store.id))
    |> Ash.run_action!()
  end

  test "the same phone with a placeholder email finds the customer made with a real email",
       %{store: store} do
    first =
      find_or_create!(store, %{
        email: "ama@example.com",
        name: "Ama Serwaa",
        phone: "+233241234567"
      })

    second =
      find_or_create!(store, %{
        email: CheckoutService.phone_placeholder_email("0241234567"),
        name: "Ama",
        phone: "0241234567"
      })

    assert second.id == first.id
  end

  test "the phone is stored normalised", %{store: store} do
    customer =
      find_or_create!(store, %{
        email: CheckoutService.phone_placeholder_email("0201112222"),
        phone: "020 111 2222"
      })

    assert customer.phone == "+233201112222"
  end

  test "an email match still wins when no phone was given", %{store: store} do
    existing = create_customer!(store, %{email: "kofi@example.com", phone: nil})

    found = find_or_create!(store, %{email: "kofi@example.com"})

    assert found.id == existing.id
  end

  test "the same phone in another store is another customer", %{store: store} do
    other = create_store!()

    here = find_or_create!(store, %{email: "a@example.com", phone: "+233241234567"})
    there = find_or_create!(other, %{email: "b@example.com", phone: "+233241234567"})

    refute here.id == there.id
  end

  test "a blank or bare-country-code phone is stored as nil, not as \"+233\"", %{store: store} do
    # Both normalise to the bare country code, with no national digits after
    # it — storing that as a real phone would find-or-create the SAME
    # customer for every buyer who typed no phone, merging unrelated people.
    whitespace = find_or_create!(store, %{email: "whitespace@example.com", phone: "   "})
    bare_code = find_or_create!(store, %{email: "barecode@example.com", phone: "+233"})

    assert whitespace.phone == nil
    assert bare_code.phone == nil
    refute whitespace.id == bare_code.id
  end
end
