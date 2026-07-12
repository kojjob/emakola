defmodule EmakolaWeb.Storefront.NoInventedPolicyCopyTest do
  @moduledoc """
  No theme may hardcode merchant delivery/returns SLAs into its templates —
  a merchant on one theme could not edit or disavow a promise ("7-day
  returns", "1-2 business days") that a different theme states differently
  for the same store. These sites must instead point to the store's real
  policies page, letting the merchant's own content be authoritative.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @all_themes ~w(atelier beauty bold electronics fashion fresh
                 home_living market pharmacy spotlight starter vibrant)

  @invented_sla ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i

  for theme <- @all_themes do
    @theme theme
    test "#{theme} PDP has no hardcoded delivery/returns SLA copy", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => @theme}})
      product = Factory.create_product!(store, %{status: :active})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      refute html =~ @invented_sla,
             "found an invented delivery/returns SLA literal in the #{@theme} PDP"
    end
  end
end
