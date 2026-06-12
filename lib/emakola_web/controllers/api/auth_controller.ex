defmodule EmakolaWeb.Api.AuthController do
  use EmakolaWeb, :controller

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{ApiTokens, Merchant}

  def sign_in(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    strategy = Info.strategy!(Merchant, :password)

    with {:ok, merchant} <-
           Strategy.action(strategy, :sign_in, %{email: email, password: password}),
         {:ok, pair} <- ApiTokens.issue_pair(merchant) do
      json(conn, %{
        data: %{
          access_token: pair.access_token,
          refresh_token: pair.refresh_token,
          expires_in: pair.expires_in,
          merchant: %{
            id: merchant.id,
            email: to_string(merchant.email),
            name: merchant.name,
            business_name: merchant.business_name
          }
        }
      })
    else
      {:error, :token_generation_failed} ->
        error(conn, 500, "token_generation_failed", "Could not issue tokens; try again")

      _ ->
        error(conn, 401, "invalid_credentials", "Invalid email or password")
    end
  end

  def sign_in(conn, _params),
    do: error(conn, 422, "missing_params", "email and password are required")

  def refresh(conn, %{"refresh_token" => token}) when is_binary(token) do
    case ApiTokens.exchange_refresh(token) do
      {:ok, pair} ->
        json(conn, %{data: pair})

      {:error, :token_generation_failed} ->
        error(conn, 500, "token_generation_failed", "Could not issue tokens; try again")

      {:error, _} ->
        error(conn, 401, "invalid_refresh_token", "Refresh token is invalid or expired")
    end
  end

  def refresh(conn, _params),
    do: error(conn, 422, "missing_params", "refresh_token is required")

  def sign_out(conn, params) do
    case params["refresh_token"] do
      token when is_binary(token) -> ApiTokens.revoke(token)
      _ -> :ok
    end

    send_resp(conn, 204, "")
  end

  defp error(conn, status, code, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), code: code, detail: detail}]})
  end
end
