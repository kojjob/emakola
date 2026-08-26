defmodule Emakola.Accounts.ConfirmationHijackGuardTest do
  @moduledoc """
  The confirmation add-on exists to arm `prevent_hijacking?`.

  OAuth registration is an UPSERT on the email identity — that is how "link my
  Google to my existing account" works. Without confirmation, that same upsert
  is an account-takeover: attacker registers a password account with the
  victim's email (unverified — anyone can type any email), waits; when the
  victim later signs in with Google, the provider-verified login silently
  LINKS INTO the attacker's account — or the reverse, the attacker's Google
  login absorbs the victim's unconfirmed account.

  The guard: an UNCONFIRMED password account can never be upserted over by an
  OAuth registration. A confirmed account links normally. Fresh-email OAuth
  registrations auto-confirm (the provider verified the address).

  Sign-in is deliberately NOT gated on confirmation — prod email delivery is
  not live yet, and locking new merchants out of their dashboards pending an
  email that cannot arrive would be worse than the risk it mitigates.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.Merchant
  alias Emakola.Customers.Customer

  defp register_merchant_password!(email) do
    Merchant
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "SuperSecret123!",
      password_confirmation: "SuperSecret123!"
    })
    |> Ash.create!(authorize?: false)
  end

  defp register_merchant_oauth(email) do
    Merchant
    |> Ash.Changeset.for_create(:register_with_oauth2, %{
      user_info: %{"email" => email, "name" => "Kwesi", "sub" => "google-#{email}"},
      oauth_tokens: %{"access_token" => "tok"}
    })
    |> Ash.create(authorize?: false)
  end

  describe "merchant password registration" do
    test "succeeds unconfirmed, and the merchant can still sign in" do
      merchant = register_merchant_password!("new@example.com")

      assert is_nil(merchant.confirmed_at)

      # Unconfirmed must NOT lock the account: sign-in works.
      assert {:ok, [_signed_in]} =
               Merchant
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: "new@example.com",
                 password: "SuperSecret123!"
               })
               |> Ash.read(authorize?: false)
    end
  end

  describe "the hijack guard (merchant)" do
    test "OAuth cannot upsert over an UNCONFIRMED password account" do
      register_merchant_password!("victim@example.com")

      assert {:error, _} = register_merchant_oauth("victim@example.com")
    end

    # GHSA-777c-2fxx-qr28. ash_authentication 4.14 refuses to attach a NEW
    # provider identity to a pre-existing local account by email alone, even a
    # confirmed one — matching on email is the takeover primitive the advisory
    # describes. Linking requires `trust_email_verified?`, opted into per
    # provider, and we have not opted in: social login is dark, and Facebook in
    # particular does not reliably assert email ownership.
    #
    # This test previously asserted the link SUCCEEDED. It now pins the refusal,
    # because that is the safer behaviour and losing it silently is the risk.
    test "OAuth will not attach itself to an existing account by email" do
      merchant = register_merchant_password!("owner@example.com")

      merchant
      |> Ash.Changeset.for_update(:update_profile, %{})
      |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
      |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{errors: errors}} =
               register_merchant_oauth("owner@example.com")

      # The caller sees a generic "Authentication failed" — the reason is not
      # leaked outward. The specific refusal lives in caused_by.
      assert Enum.any?(errors, fn
               %AshAuthentication.Errors.AuthenticationFailed{caused_by: %{message: m}} ->
                 m =~ "could not be verified"

               _ ->
                 false
             end)
    end

    test "a fresh-email OAuth registration is auto-confirmed — the provider verified it" do
      assert {:ok, merchant} = register_merchant_oauth("fresh@example.com")
      refute is_nil(merchant.confirmed_at)
    end
  end

  describe "the hijack guard (customer, per-store)" do
    setup do
      {_merchant, store} = Emakola.Factory.create_merchant_with_store!()
      %{store: store}
    end

    defp register_customer_password!(email, store_id) do
      Customer
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          password: "SuperSecret123!",
          password_confirmation: "SuperSecret123!",
          store_id: store_id
        },
        tenant: store_id
      )
      |> Ash.create!(authorize?: false)
    end

    defp register_customer_oauth(email, store_id) do
      Customer
      |> Ash.Changeset.for_create(
        :register_with_oauth2,
        %{
          # `sub` is required now that customer OAuth stores the provider's
          # stable id. Matching on email alone is what the advisory calls unsafe.
          user_info: %{"email" => email, "name" => "Ama", "sub" => "google-#{email}"},
          oauth_tokens: %{"access_token" => "tok"}
        },
        tenant: store_id
      )
      |> Ash.create(authorize?: false)
    end

    test "OAuth cannot upsert over a password customer (no email confirmation flow yet)",
         %{store: store} do
      register_customer_password!("shopper@example.com", store.id)

      assert {:error, _} = register_customer_oauth("shopper@example.com", store.id)
    end

    test "a fresh-email OAuth customer is created and auto-confirmed", %{store: store} do
      assert {:ok, customer} = register_customer_oauth("oauth-only@example.com", store.id)
      refute is_nil(customer.confirmed_at)
    end
  end
end
