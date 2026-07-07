defmodule EmakolaWeb.Plugs.PublicStoreTenant do
  @moduledoc """
  Resolves the `:store_slug` path param to an ACTIVE store and sets it as the
  Ash tenant for the public browse API. PUBLIC — no auth/actor.

  FAIL-CLOSED: this is the only guard against the browse actions' `global?(true)`
  tenantless cross-store leak. Any failure to resolve a valid active store —
  missing param, unknown slug, inactive store, or a resolver error — is a 404 +
  halt with NO tenant set. There is no fall-through path.
  """

  @behaviour Plug

  import Plug.Conn

  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with slug when is_binary(slug) <- conn.path_params["store_slug"],
         {:ok, %{active: true} = store} <- StoreResolver.resolve(slug) do
      conn
      |> Ash.PlugHelpers.set_tenant(store.id)
      |> assign(:shop_store, store)
    else
      _ -> not_found(conn)
    end
  end

  defp not_found(conn) do
    conn
    |> put_resp_content_type("application/vnd.api+json", nil)
    |> send_resp(
      404,
      Jason.encode!(%{
        errors: [
          %{status: "404", code: "store_not_found", detail: "Store not found"}
        ]
      })
    )
    |> halt()
  end
end
