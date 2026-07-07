defmodule EmakolaWeb.Api.ShopController do
  use EmakolaWeb, :controller

  def show(conn, _params) do
    store = conn.assigns.shop_store

    json(conn, %{
      data: %{
        type: "store",
        id: store.id,
        attributes: %{
          name: store.name,
          slug: store.slug,
          currency: store.currency,
          logo_url: store.logo_url
        }
      }
    })
  end
end
