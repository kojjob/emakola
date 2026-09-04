defmodule EmakolaWeb.SessionInvalidationTest do
  @moduledoc """
  Password reset must lock out anyone holding an old credential.

  Browser sessions are signed `Phoenix.Token` subjects, not rows — verifying
  one proves only that we minted it. Revoking Ash token rows alone leaves a
  stolen cookie working for its full 30-day life, which would make reset
  useless against the exact attack it exists to stop.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Accounts.Merchant
  alias EmakolaWeb.AuthTokens

  defp register_merchant! do
    email = "session-#{System.unique_integer([:positive])}@example.com"

    merchant =
      Merchant
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: "Password123!", password_confirmation: "Password123!"},
        authorize?: false
      )
      |> Ash.create!()
      |> Emakola.Factory.confirm!()

    {merchant, email}
  end

  defp conn_with_session(conn, token) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  test "a session minted before a reset stops working after it", %{conn: conn} do
    {merchant, _email} = register_merchant!()

    # The "attacker's" cookie: a perfectly valid session minted pre-reset.
    stolen = AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    # Recognised: a store-less merchant is sent to onboarding — not to login,
    # which is what an unrecognised session gets.
    assert {:error, {:live_redirect, %{to: "/onboarding"}}} =
             live(conn_with_session(conn, stolen), ~p"/dashboard")

    :ok = Emakola.Accounts.revoke_all_sessions_for(merchant)

    assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
             live(conn_with_session(conn, stolen), ~p"/dashboard")
  end

  test "onboarding stops recognising an invalidated session", %{conn: conn} do
    {merchant, _email} = register_merchant!()
    store = Emakola.Factory.create_store!()
    Emakola.Factory.create_store_membership!(merchant, store, :owner)

    stolen = AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    # Recognised: an onboarded merchant is bounced straight to the dashboard.
    assert {:error, {:live_redirect, %{to: "/dashboard"}}} =
             live(conn_with_session(conn, stolen), ~p"/onboarding")

    :ok = Emakola.Accounts.revoke_all_sessions_for(merchant)

    # No longer recognised: treated as an anonymous visitor, so the wizard
    # renders instead of the "already onboarded" bounce.
    assert {:ok, _view, _html} = live(conn_with_session(conn, stolen), ~p"/onboarding")
  end

  test "a session minted after the reset works — no permanent lockout", %{conn: conn} do
    {merchant, _email} = register_merchant!()

    :ok = Emakola.Accounts.revoke_all_sessions_for(merchant)

    # Issued-at is whole seconds and the check is strictly-after, so cross a
    # real second boundary — in the product this gap is the page redirect plus
    # however long it takes to type a password.
    Process.sleep(1_100)

    merchant = Ash.get!(Merchant, merchant.id, authorize?: false)
    fresh = AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    # Recognised again: onboarding, not the login page.
    assert {:error, {:live_redirect, %{to: "/onboarding"}}} =
             live(conn_with_session(conn, fresh), ~p"/dashboard")
  end

  describe "unreadable token payloads" do
    test "a payload this build cannot parse logs the visitor out instead of crashing" do
      # A cookie whose payload is a bare map with unexpected keys — the shape a
      # build sees when the token format changed under it. Previously this fell
      # through to subject_to_user/2, which called to_string/1 on the map and
      # crashed the page with String.Chars not implemented for Map.
      signed =
        Phoenix.Token.sign(EmakolaWeb.Endpoint, "auth_subject_v1", %{"unexpected" => "shape"})

      assert {:error, :unreadable_payload} = AuthTokens.verify_subject_with_iat(signed)
      assert {:error, :unreadable_payload} = AuthTokens.verify_subject(signed)
    end

    test "an unreadable cookie renders the page as logged out, not a 500", %{conn: conn} do
      signed =
        Phoenix.Token.sign(EmakolaWeb.Endpoint, "auth_subject_v1", %{"unexpected" => "shape"})

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn_with_session(conn, signed), ~p"/dashboard")
    end

    test "a well-formed payload with a non-binary sub is also rejected" do
      signed =
        Phoenix.Token.sign(EmakolaWeb.Endpoint, "auth_subject_v1", %{"sub" => 123, "iat" => 1})

      assert {:error, :unreadable_payload} = AuthTokens.verify_subject_with_iat(signed)
    end
  end

  describe "session_live?/2" do
    test "an untouched merchant accepts any issued-at" do
      assert Emakola.Accounts.session_live?(%{sessions_valid_from: nil}, 0)
    end

    test "legacy tokens (issued_at 0) die once a cutoff is set" do
      cutoff = DateTime.utc_now()
      refute Emakola.Accounts.session_live?(%{sessions_valid_from: cutoff}, 0)
    end

    test "only tokens issued strictly after the cutoff survive" do
      cutoff = DateTime.utc_now()
      at = DateTime.to_unix(cutoff)

      assert Emakola.Accounts.session_live?(%{sessions_valid_from: cutoff}, at + 1)
      assert Emakola.Accounts.session_live?(%{sessions_valid_from: cutoff}, at + 60)
      # Issued-at is whole seconds, so same-second must fail closed — otherwise
      # a session minted in the same second as the reset outlives it.
      refute Emakola.Accounts.session_live?(%{sessions_valid_from: cutoff}, at)
      refute Emakola.Accounts.session_live?(%{sessions_valid_from: cutoff}, at - 1)
    end
  end
end
