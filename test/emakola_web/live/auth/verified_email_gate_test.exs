defmodule EmakolaWeb.VerifiedEmailGateTest do
  @moduledoc """
  An unverified address must not reach the app.

  Sign-in used to ignore `confirmed_at` on purpose — the account could not be
  OAuth-linked, so it was safe, and prod email delivery was unreliable. The
  rule is stricter now: proving you own the address is the price of entry.

  Two doors, and both have to hold. The obvious one is the login form. The
  other is an existing session: someone who signed in before the gate landed,
  or who was verified and then had it revoked, must not keep their run of the
  app just because they already hold a cookie.
  """

  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "the login form" do
    test "an unverified merchant is not signed in, and is told why", %{conn: conn} do
      merchant = Factory.create_merchant!(confirmed_at: nil, password: "Password123!")

      {:ok, view, _html} = live(conn, ~p"/auth/login")

      result =
        view
        |> form("form[phx-submit=login]",
          user: %{email: to_string(merchant.email), password: "Password123!"}
        )
        |> render_submit()

      # Sent somewhere they can fix it, not told "invalid email or password":
      # the password was right, and pointing them at a password reset that
      # cannot help is how support tickets are made.
      assert {:error, {:redirect, %{to: to}}} = result
      assert to =~ "/auth/verify"
    end

    test "a verified merchant signs in as before", %{conn: conn} do
      merchant = Factory.create_merchant!(password: "Password123!")

      {:ok, view, _html} = live(conn, ~p"/auth/login")

      view
      |> form("form[phx-submit=login]",
        user: %{email: to_string(merchant.email), password: "Password123!"}
      )
      |> render_submit()

      assert_redirect(view)
    end
  end

  describe "the address itself" do
    test "registration refuses something that is not an email address" do
      for junk <- ["notanemail", "no@domain", "spaces in@example.com", "@example.com"] do
        assert {:error, _} =
                 Emakola.Accounts.Merchant
                 |> Ash.Changeset.for_create(:register_with_password, %{
                   email: junk,
                   password: "Password123!",
                   password_confirmation: "Password123!"
                 })
                 |> Ash.create(authorize?: false),
               "#{junk} was accepted as an email address"
      end
    end

    test "a real address still registers" do
      assert {:ok, _merchant} =
               Emakola.Accounts.Merchant
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "ama-#{System.unique_integer([:positive])}@kentekingdom.com",
                 password: "Password123!",
                 password_confirmation: "Password123!"
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "an existing session" do
    test "an unverified merchant holding a session cannot reach the admin", %{conn: conn} do
      {conn, merchant, _store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)

      merchant
      |> Ash.Changeset.for_update(:update_profile, %{})
      |> Ash.Changeset.force_change_attribute(:confirmed_at, nil)
      |> Ash.update!(authorize?: false)

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/admin/products")
      assert path =~ "/auth"
    end

    test "a verified merchant keeps their session", %{conn: conn} do
      {conn, _merchant, _store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)

      assert {:ok, _view, _html} = live(conn, ~p"/admin/products")
    end
  end
end
