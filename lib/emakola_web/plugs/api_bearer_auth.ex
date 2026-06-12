defmodule EmakolaWeb.Plugs.ApiBearerAuth do
  @moduledoc """
  Authenticates `/api/v1` requests via `Authorization: Bearer <access token>`.

  Delegates verification to `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3`
  (signature, expiry, jti presence with purpose "user", revocation), then
  promotes the loaded merchant to the Ash actor. Tokens signed for other
  resources (e.g. platform staff Users) do not produce a `current_merchant`
  assign and are rejected.
  """

  @behaviour Plug

  import Plug.Conn

  alias AshAuthentication.Plug.Helpers

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # Clear any pre-existing assign so the plug's verdict never depends on
    # what earlier pipeline plugs may have loaded (e.g. session identity).
    conn =
      conn
      |> assign(:current_merchant, nil)
      |> Helpers.retrieve_from_bearer(:emakola)

    case conn.assigns[:current_merchant] do
      %Emakola.Accounts.Merchant{} = merchant ->
        Ash.PlugHelpers.set_actor(conn, merchant)

      _ ->
        conn
        |> put_resp_content_type("application/vnd.api+json", nil)
        |> send_resp(
          401,
          Jason.encode!(%{
            errors: [
              %{status: "401", code: "unauthorized", detail: "Invalid or expired access token"}
            ]
          })
        )
        |> halt()
    end
  end
end
