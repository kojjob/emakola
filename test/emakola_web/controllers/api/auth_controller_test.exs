defmodule EmakolaWeb.Api.AuthControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    merchant = create_merchant!(%{password: "Password123!"})
    {:ok, conn: put_unique_peer_ip(conn), merchant: merchant}
  end

  describe "POST /api/v1/auth/sign_in" do
    test "returns token pair for valid credentials", %{conn: conn, merchant: merchant} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => to_string(merchant.email),
          "password" => "Password123!"
        })

      assert %{
               "data" => %{
                 "access_token" => access,
                 "refresh_token" => refresh,
                 "expires_in" => 900,
                 "merchant" => %{"id" => id, "email" => _}
               }
             } = json_response(conn, 200)

      assert id == merchant.id
      assert is_binary(access) and is_binary(refresh)
    end

    test "401 with opaque error for wrong password", %{conn: conn, merchant: merchant} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => to_string(merchant.email),
          "password" => "wrong"
        })

      assert %{"errors" => [%{"status" => "401", "code" => "invalid_credentials"}]} =
               json_response(conn, 401)
    end

    test "401 for unknown email (no account enumeration)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => "nobody@example.com",
          "password" => "Password123!"
        })

      assert %{"errors" => [%{"code" => "invalid_credentials"}]} = json_response(conn, 401)
    end

    test "422 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/sign_in", %{})
      assert %{"errors" => [%{"status" => "422"}]} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "rotates the pair", %{conn: conn, merchant: merchant} do
      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn1 = post(conn, ~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})

      assert %{"data" => %{"access_token" => _, "refresh_token" => new_refresh}} =
               json_response(conn1, 200)

      conn2 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})

      assert json_response(conn2, 401)

      conn3 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => new_refresh})

      assert json_response(conn3, 200)
    end

    test "401 for garbage", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/refresh", %{"refresh_token" => "garbage"})
      assert json_response(conn, 401)
    end

    test "422 when refresh_token missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/refresh", %{})
      assert json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    test "revokes the refresh token", %{conn: conn, merchant: merchant} do
      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn1 = delete(conn, ~p"/api/v1/auth/sign_out", %{"refresh_token" => pair.refresh_token})
      assert response(conn1, 204)

      conn2 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})

      assert json_response(conn2, 401)
    end

    test "204 even without a token", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/auth/sign_out", %{})
      assert response(conn, 204)
    end
  end
end
