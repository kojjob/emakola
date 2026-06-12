defmodule EmakolaWeb.ApiRouter do
  @moduledoc """
  JSON:API router for /api/v1 (ash_json_api). Mounted behind ApiBearerAuth +
  ApiTenant in the Phoenix router — actor and tenant arrive via
  Ash.PlugHelpers conn assigns.
  """

  use AshJsonApi.Router,
    domains: [Emakola.Orders],
    open_api: "/open_api"
end
