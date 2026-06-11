defmodule EmakolaWeb.Platform.InviteAcceptLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.User

  @password "Password123!"
  @generic_copy "This invite link is invalid or has been revoked."

  defp create_invite(attrs \\ %{}) do
    owner = create_platform_owner!()

    invite =
      attrs
      |> Map.new()
      |> Map.put_new(:invited_by_id, owner.id)
      |> create_platform_invite!()

    {invite, invite.__metadata__.raw_token}
  end

  defp get_user_by_email(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
  end

  describe "mount classification" do
    test "unknown token shows the generic invalid copy and no form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/platform/invite/accept/no-such-token")

      assert html =~ @generic_copy
      refute html =~ "platform-invite-form"
    end

    test "revoked invite shows exactly the same copy as an invalid one", %{conn: conn} do
      {invite, raw} = create_invite()
      invite |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      {:ok, _view, html} = live(conn, "/platform/invite/accept/#{raw}")

      assert html =~ @generic_copy
      refute html =~ "expired"
      refute html =~ "platform-invite-form"
    end

    test "expired invite asks for a fresh one", %{conn: conn} do
      {_invite, raw} =
        create_invite(%{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)})

      {:ok, _view, html} = live(conn, "/platform/invite/accept/#{raw}")

      assert html =~ "expired"
      assert html =~ "ask an owner to send a new one"
      refute html =~ "platform-invite-form"
    end

    test "already-accepted invite redirects to login with an info flash", %{conn: conn} do
      {invite, raw} = create_invite()
      invite |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update!()

      assert {:error, {:redirect, %{to: "/platform/login", flash: flash}}} =
               live(conn, "/platform/invite/accept/#{raw}")

      assert flash["info"] =~ "already been used"
    end

    test "pending invite shows the form with the email read-only", %{conn: conn} do
      {invite, raw} = create_invite()

      {:ok, _view, html} = live(conn, "/platform/invite/accept/#{raw}")

      assert html =~ "platform-invite-form"
      assert html =~ to_string(invite.email)
      assert html =~ ~s(autocomplete="new-password")
    end
  end

  describe "submit" do
    test "happy path creates the staff user and redirects to login", %{conn: conn} do
      {invite, raw} = create_invite(%{permissions: [:manage_stores]})

      {:ok, view, _html} = live(conn, "/platform/invite/accept/#{raw}")

      view
      |> form("#platform-invite-form",
        user: %{
          name: "New Staff",
          password: @password,
          password_confirmation: @password
        }
      )
      |> render_submit()

      flash = assert_redirect(view, "/platform/login")

      assert flash["info"] =~ "Account created"
      assert flash["info"] =~ "two-factor"

      user = get_user_by_email(to_string(invite.email))
      assert %DateTime{} = user.confirmed_at
      assert user.platform_permissions == [:manage_stores]
      refute user.is_owner

      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).accepted_at
    end

    test "weak password shows form errors and creates no user", %{conn: conn} do
      {invite, raw} = create_invite()

      {:ok, view, _html} = live(conn, "/platform/invite/accept/#{raw}")

      html =
        view
        |> form("#platform-invite-form",
          user: %{name: "X", password: "short", password_confirmation: "short"}
        )
        |> render_submit()

      assert html =~ "platform-invite-form"
      assert html =~ "Password"
      assert get_user_by_email(to_string(invite.email)) == nil
    end

    test "email taken between invite and accept directs to login", %{conn: conn} do
      {invite, raw} = create_invite()

      {:ok, view, _html} = live(conn, "/platform/invite/accept/#{raw}")

      create_user!(email: to_string(invite.email))

      html =
        view
        |> form("#platform-invite-form",
          user: %{name: "Late", password: @password, password_confirmation: @password}
        )
        |> render_submit()

      assert html =~ "already exists"
      assert html =~ "sign in"
    end
  end
end
