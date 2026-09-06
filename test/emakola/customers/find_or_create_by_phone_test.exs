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

  describe "an unverified match never reuses a credentialed row" do
    defp register!(store, phone) do
      Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "owner-#{System.unique_integer([:positive])}@example.com",
        name: "Account Owner",
        phone: phone,
        store_id: store.id,
        password: "password123",
        password_confirmation: "password123"
      })
      |> Ash.create!(authorize?: false)
    end

    test "a guest checkout with the account's phone gets a different, credential-less customer",
         %{store: store} do
      owner = register!(store, "+233241234567")

      guest =
        find_or_create!(store, %{
          email: CheckoutService.phone_placeholder_email("+233241234567"),
          name: "Whoever Just Checked Out",
          phone: "+233241234567"
        })

      refute guest.id == owner.id
      assert guest.phone == nil
      assert to_string(guest.email) == CheckoutService.phone_placeholder_email("+233241234567")
      assert guest.hashed_password == nil
    end

    test "a second guest checkout with the same phone reuses the same credential-less row",
         %{store: store} do
      register!(store, "+233241234567")

      first =
        find_or_create!(store, %{
          email: CheckoutService.phone_placeholder_email("+233241234567"),
          name: "Guest One",
          phone: "+233241234567"
        })

      second =
        find_or_create!(store, %{
          email: CheckoutService.phone_placeholder_email("+233241234567"),
          name: "Guest Two",
          phone: "+233241234567"
        })

      assert second.id == first.id
    end

    test "verified?: true returns the credentialed row itself", %{store: store} do
      owner = register!(store, "+233241234567")

      found =
        Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: CheckoutService.phone_placeholder_email("+233241234567"),
          name: "Account Owner",
          phone: "+233241234567",
          store_id: store.id,
          verified?: true
        })
        |> Ash.run_action!()

      assert found.id == owner.id
    end

    test "a credentialed row squatting on the placeholder email is a conflict, not a match",
         %{store: store} do
      placeholder = CheckoutService.phone_placeholder_email("+233241234567")

      # NotPlaceholderEmail now forbids any registration from claiming this
      # email — this builds the state directly, the way an attacker's row
      # would have looked before that validation existed, via the one
      # action (:create) that validation is not attached to.
      Customer
      |> Ash.Changeset.for_create(:create, %{
        email: placeholder,
        store_id: store.id,
        name: "Attacker",
        phone: "+233241234567"
      })
      |> Ash.Changeset.force_change_attribute(:hashed_password, "hashed")
      |> Ash.create!(authorize?: false)

      result =
        Customer
        |> Ash.ActionInput.for_action(:find_or_create, %{
          email: placeholder,
          name: "Victim",
          phone: "+233241234567",
          store_id: store.id
        })
        |> Ash.run_action()

      # Ash.run_action/2 wraps a plain atom error from a generic action's
      # run/3 in Ash.Error.Unknown — Exception.message/1 is how the rest of
      # this test suite already asserts on such errors (customer_auth_test,
      # phone_only_customer_test). CheckoutService.find_or_create_customer!/2
      # rolls back on ANY {:error, _} regardless of shape, so this doesn't
      # affect the actual checkout-facing behaviour.
      assert {:error, error} = result
      assert Exception.message(error) =~ "customer_identity_conflict"
      assert Customer |> Ash.count!(authorize?: false) == 1
    end
  end
end
