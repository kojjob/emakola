defmodule EmakolaWeb.Plugs.ShopApiForward do
  @moduledoc """
  Mounts the public JSON:API browse router (`EmakolaWeb.ShopApiRouter`) under
  `/api/v1/shop/:store_slug`.

  Phoenix `forward` rejects a dynamic path segment, so the store slug cannot be a
  Phoenix route param on the forward. This plug bridges the gap: it pops the slug
  off `path_info`, runs the (unchanged) `PublicStoreTenant` plug to resolve the
  ACTIVE store and set the Ash tenant — FAIL-CLOSED on an unknown/inactive/missing
  slug — and only then `Plug.forward`s the remaining path (e.g. `["products"]`) to
  the ash_json_api router. The tenant is therefore ALWAYS set before any browse
  action runs (the `global?(true)` cross-store leak guard).
  """

  @behaviour Plug

  alias EmakolaWeb.Plugs.PublicStoreTenant
  alias EmakolaWeb.ShopApiRouter

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: [slug | rest]} = conn, _opts) do
    conn = %{conn | path_params: Map.put(conn.path_params, "store_slug", slug)}

    case PublicStoreTenant.call(conn, PublicStoreTenant.init([])) do
      %Plug.Conn{halted: true} = halted ->
        halted

      conn ->
        # Drop store_slug before handing off: ash_json_api treats leftover
        # path_params as action inputs and 422s on unknown ones.
        conn = %{conn | path_params: Map.delete(conn.path_params, "store_slug")}
        Plug.forward(conn, rest, ShopApiRouter, ShopApiRouter.init([]))
    end
  end

  def call(conn, _opts) do
    # No slug segment — let PublicStoreTenant fail closed (404).
    PublicStoreTenant.call(conn, PublicStoreTenant.init([]))
  end
end
