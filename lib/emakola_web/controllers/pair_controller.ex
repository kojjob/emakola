defmodule EmakolaWeb.PairController do
  @moduledoc """
  The last step of scan-to-sign-in, and the only part that can actually sign
  anyone in.

  A merchant session is a signed subject token in the session cookie, and a
  LiveView cannot write cookies — so `EmakolaWeb.PairLive` redirects here once
  the desktop has confirmed, and this is where the exchange happens.

  Everything that makes the exchange safe lives in
  `Emakola.Accounts.DevicePairings.redeem/1`: the code must be confirmed, must
  be unexpired, and is consumed under a row lock so it cannot be spent twice.
  This controller's own job is small — take the merchant it returns and put a
  session on the connection.
  """
  use EmakolaWeb, :controller

  require Logger

  alias Emakola.Accounts.DevicePairings
  alias EmakolaWeb.AuthTokens

  def complete(conn, %{"token" => token}) do
    case DevicePairings.redeem(token) do
      {:ok, merchant} ->
        Logger.info("[pairing] device paired for merchant=#{merchant.id}")

        conn
        |> put_session(
          :user_token,
          AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))
        )
        # renew: true so the paired phone gets a fresh session id rather than
        # continuing whatever anonymous session it arrived with.
        |> configure_session(renew: true)
        |> redirect(to: ~p"/dashboard")

      {:error, reason} ->
        # Deliberately one message for every failure. Distinguishing "expired"
        # from "already used" from "never existed" would tell whoever is holding
        # a stray code which of those it is.
        Logger.info("[pairing] redemption refused: #{inspect(reason)}")

        conn
        |> put_flash(:error, "That sign-in code didn't work. Ask for a new one.")
        |> redirect(to: ~p"/auth/login")
    end
  end
end
