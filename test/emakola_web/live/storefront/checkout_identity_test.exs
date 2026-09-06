defmodule EmakolaWeb.Storefront.CheckoutIdentityTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Storefront.CheckoutIdentity

  test "a signed-in buyer is themselves" do
    assert CheckoutIdentity.opts(%{
             current_customer: %{id: "c-1"},
             phone: "0241234567",
             fullname: "Ama",
             email: ""
           }) == [customer_id: "c-1"]
  end

  test "a guest with a phone and no email gets the phone placeholder" do
    opts =
      CheckoutIdentity.opts(%{
        current_customer: nil,
        phone: "0241234567",
        fullname: "Ama",
        email: ""
      })

    assert opts[:customer_phone] == "+233241234567"
    assert opts[:customer_name] == "Ama"
    assert opts[:customer_email] == "p233241234567@phone.customers.makola.io"
    refute Keyword.has_key?(opts, :customer_id)
  end

  test "a guest who typed an email keeps it" do
    opts =
      CheckoutIdentity.opts(%{
        current_customer: nil,
        phone: "+233241234567",
        fullname: "Ama",
        email: "ama@example.com"
      })

    assert opts[:customer_email] == "ama@example.com"
  end

  test "a guest with a blank phone gets no customer at all" do
    # PhoneAuth.normalize("") and normalize("   ") both collapse to the
    # bare country code "+233" — without this guard every blank-phone guest
    # in a store would be found-or-created into the SAME customer row.
    assert CheckoutIdentity.opts(%{current_customer: nil, phone: "", fullname: "Ama", email: ""}) ==
             []

    assert CheckoutIdentity.opts(%{
             current_customer: nil,
             phone: "   ",
             fullname: "Ama",
             email: ""
           }) == []
  end
end
