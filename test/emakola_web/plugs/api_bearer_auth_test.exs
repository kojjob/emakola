defmodule EmakolaWeb.Plugs.ApiBearerAuthTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.Plugs.ApiBearerAuth

  defp call(conn) do
    ApiBearerAuth.call(conn, ApiBearerAuth.init([]))
  end

  test "valid access token sets the merchant as Ash actor", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> call()

    refute conn.halted
    assert %Emakola.Accounts.Merchant{} = actor = Ash.PlugHelpers.get_actor(conn)
    assert actor.id == merchant.id
  end

  test "missing header → 401 JSON:API error", %{conn: conn} do
    conn = call(conn)

    assert conn.halted
    assert conn.status == 401
    assert %{"errors" => [%{"status" => "401"}]} = Jason.decode!(conn.resp_body)
  end

  test "garbage token → 401", %{conn: conn} do
    conn = conn |> put_req_header("authorization", "Bearer garbage") |> call()
    assert conn.halted
    assert conn.status == 401
  end

  test "refresh token used as access token → 401", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn = conn |> put_req_header("authorization", "Bearer #{pair.refresh_token}") |> call()
    assert conn.halted
    assert conn.status == 401
  end

  test "revoked access token → 401", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    :ok =
      AshAuthentication.TokenResource.Actions.revoke(
        Emakola.Accounts.Token,
        pair.access_token
      )

    conn = conn |> put_req_header("authorization", "Bearer #{pair.access_token}") |> call()
    assert conn.halted
    assert conn.status == 401
  end

  test "token signed for a platform User (not Merchant) → 401", %{conn: conn} do
    # User lacks store_all_tokens?/require_token_presence_for_authentication?, so even
    # if the JWT signature verifies, retrieve_from_bearer sets current_user (not
    # current_merchant). The plug rejects it because conn.assigns[:current_merchant]
    # is nil.
    user = create_user!()

    {:ok, user_token, _claims} =
      AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "user"},
        token_lifetime: {15, :minutes}
      )

    conn = conn |> put_req_header("authorization", "Bearer #{user_token}") |> call()
    assert conn.halted
    assert conn.status == 401
  end
end
