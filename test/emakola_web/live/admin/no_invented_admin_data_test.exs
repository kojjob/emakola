defmodule EmakolaWeb.Admin.NoInventedAdminDataTest do
  @moduledoc """
  Real merchants must never be shown numbers describing nobody's shop.

  `/admin/discounts` rendered `placeholder_discounts/0` — invented codes,
  usage counts and date ranges — while the sidebar linked merchants to it and
  left the REAL coupons page (working CRUD on `Marketing.Coupon`) unlinked.
  `/admin/campaigns` rendered `sample_campaigns/0`, including "89% Opened"
  and "34% Clicked", neither of which this platform can measure.

  Same class as the storefront invented-copy debt and the revenue/reports
  fabrications: a guard, not a one-off cleanup.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @invented ~w(placeholder_discounts sample_campaigns)

  test "no admin LiveView ships a hardcoded sample-data function" do
    offenders =
      "lib/emakola_web/live/admin/**/*.ex"
      |> Path.wildcard()
      |> Enum.filter(fn file ->
        source = File.read!(file)
        # Match a DEFINITION, not a mention — a moduledoc explaining why the
        # invented data was removed must not itself trip the guard.
        Enum.any?(@invented, &(source =~ ~r/^\s*defp?\s+#{&1}\b/m))
      end)

    assert offenders == [],
           "these admin pages build rows from invented data instead of the " <>
             "merchant's own: " <> inspect(offenders)
  end

  test "the sidebar links Discounts at the real coupons page" do
    sidebar = File.read!("lib/emakola_web/components/sidebar_components.ex")

    refute sidebar =~ ~s|href="/admin/discounts"|,
           "the sidebar still points merchants at the placeholder discounts page"

    assert sidebar =~ ~s|href="/admin/coupons"|,
           "the real coupons page must be reachable from the sidebar"
  end

  describe "the old discounts URL" do
    setup do
      {merchant, _store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn}
    end

    test "sends merchants to coupons rather than 404ing a bookmark", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/coupons"}}} =
               live(conn, "/admin/discounts")
    end
  end
end
