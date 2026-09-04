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

    test "registering sends one email, the one that unlocks the account" do
      # A "welcome" mail used to go out alongside the confirmation. To a
      # merchant who does not read well that is the same message twice, and
      # the one that mattered was the second. The confirmation is the welcome.
      {:ok, _merchant} =
        Emakola.Accounts.Merchant
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "efua-#{System.unique_integer([:positive])}@kentekingdom.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.create(authorize?: false)

      assert ["Confirm your Makola email"] == sent_subjects()
    end
  end

  describe "the verify page" do
    # Tapping Resend did nothing visible: get_connect_info/2 may only be read
    # during mount, so asking for the caller's IP inside the handler crashed
    # the LiveView, which remounted so fast the page looked untouched. And the
    # auth live_session renders no flash container, so the put_flash that was
    # supposed to reassure the merchant had nowhere to appear.
    test "resending says so on the page", %{conn: conn} do
      merchant = Factory.create_merchant!(confirmed_at: nil)

      {:ok, view, html} = live(conn, ~p"/auth/verify?email=#{to_string(merchant.email)}")
      refute html =~ "Sent."

      assert view |> element("[phx-click=resend]") |> render_click() =~ "Sent."
    end

    test "the page survives the resend rather than remounting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/auth/verify?email=nobody@example.com")

      render_click(element(view, "[phx-click=resend]"))

      # A crash would take the pid with it; the same view still answers.
      assert render(view) =~ "Check your email"
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

  # Swoosh's test adapter posts every delivery to the calling process.
  defp sent_subjects(acc \\ []) do
    receive do
      {:email, %Swoosh.Email{subject: subject}} -> sent_subjects([subject | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end
end
