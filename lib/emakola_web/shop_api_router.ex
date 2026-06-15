defmodule EmakolaWeb.ShopApiRouter do
  @moduledoc "Public, store-scoped JSON:API browse surface (ash_json_api). Tenant set by PublicStoreTenant before forward."
  use AshJsonApi.Router, domains: [Emakola.Catalog], open_api: "/open_api"
end
