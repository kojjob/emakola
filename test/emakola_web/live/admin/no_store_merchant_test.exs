defmodule EmakolaWeb.Admin.NoStoreMerchantTest do
  @moduledoc """
  A merchant who has signed up but not created a store can reach the whole
  admin: `RequireActiveStore` says so explicitly ("A merchant still onboarding
  (no store yet) passes through untouched"). Every store-backed page therefore
  has to tolerate `current_store == nil`.

  Two pages did not, and both returned "Something broke." on production on
  2026-08-24 — `/admin/settings/supply-network` raised `(KeyError) key :id not
  found in: nil`, and `/admin/settings` raised a `FunctionClauseError` from
  `QR.store_svg/2`. This walks the parameterless admin routes so the next one
  is caught here instead of by a merchant.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  # Parameterless routes in the :app live_session. Routes needing an :id are
  # excluded — they need a record, which a store-less merchant cannot own.
  @routes ~w(
    /dashboard
    /admin/campaigns
    /admin/categories
    /admin/content/media
    /admin/content/pages
    /admin/content/posts
    /admin/coupons
    /admin/customers
    /admin/design
    /admin/discounts
    /admin/earnings
    /admin/inventory
    /admin/orders
    /admin/pages
    /admin/pay-links
    /admin/payments
    /admin/payouts
    /admin/products
    /admin/reports
    /admin/returns
    /admin/revenue
    /admin/reviews
    /admin/seo
    /admin/settings
    /admin/settings/address
    /admin/settings/delivery
    /admin/settings/suppliers
    /admin/settings/supply-network
    /admin/supply/catalog
    /admin/supply/offers
    /admin/theme
    /admin/verification
  )

  setup do
    merchant = Factory.create_merchant!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn}
  end

  test "no admin page crashes for a merchant with no store", %{conn: conn} do
    failures =
      Enum.flat_map(@routes, fn route ->
        try do
          case live(conn, route) do
            {:ok, _view, _html} -> []
            # A redirect is a deliberate answer (onboarding, store-locked),
            # not a crash — only a raise is a bug.
            {:error, {kind, _}} when kind in [:live_redirect, :redirect] -> []
            other -> [{route, inspect(other)}]
          end
        rescue
          error -> [{route, Exception.message(error)}]
        end
      end)

    assert failures == [],
           "these admin pages raise for a merchant with no store:\n" <>
             Enum.map_join(failures, "\n", fn {route, why} -> "  #{route} — #{why}" end)
  end
end
