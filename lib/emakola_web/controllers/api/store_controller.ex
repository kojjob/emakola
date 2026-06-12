defmodule EmakolaWeb.Api.StoreController do
  use EmakolaWeb, :controller

  require Ash.Query

  alias Emakola.Accounts.StoreMembership

  def index(conn, _params) do
    merchant = Ash.PlugHelpers.get_actor(conn)

    memberships =
      StoreMembership
      |> Ash.Query.filter(merchant_id == ^merchant.id)
      |> Ash.Query.load(:store)
      |> Ash.read!(authorize?: false)

    json(conn, %{
      data:
        Enum.map(memberships, fn m ->
          %{
            id: m.store.id,
            name: m.store.name,
            slug: m.store.slug,
            currency: m.store.currency,
            role: m.role
          }
        end)
    })
  end
end
