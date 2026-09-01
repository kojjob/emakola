defmodule EmakolaWeb.Admin.PartnersHubTest do
  @moduledoc """
  The Partners page as a hub: numbers, the First Money strip, partner rows
  with their counts, and one door per Earn tool that leads to the tools
  page. The section flows themselves are covered in
  supply_network_live_test.exs against /tools.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.Network

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    partner = create_store!(name: "Accra Wholesale", slug: "accra-wholesale")
    partner_merchant = create_merchant!()
    create_store_membership!(partner_merchant, partner, :owner)

    %{
      conn: conn,
      merchant: merchant,
      store: store,
      partner: partner,
      partner_merchant: partner_merchant
    }
  end

  test "an empty network shows zeros, the strip, and the doors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")

    assert has_element?(view, "#supply-network-page")
    assert has_element?(view, "#partners-stats [data-stat='partners']", "0")
    assert has_element?(view, "#partners-stats [data-stat='fulfil']", "Nothing waiting")

    assert has_element?(
             view,
             "#first-money-journey #first-money-step-connected[data-complete='false']"
           )

    assert has_element?(view, "#connections-empty")
    assert has_element?(view, "#supply-connection-form")
    assert has_element?(view, "#earn-tools #earn-tool-content-studio", "No drafts yet")
    assert has_element?(view, "#earn-tools #earn-tool-income-plan", "Set a target")

    assert has_element?(
             view,
             "#earn-tools a[href='/admin/settings/supply-network/tools/commerce-passport']"
           )

    refute has_element?(view, "#hustle-autopilot")
  end

  test "an incoming invite is a row with Accept and Decline, and the tile says so", ctx do
    {:ok, connection} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network")

    assert has_element?(view, "#partners-stats [data-stat='partners']", "1 invite waiting")
    assert has_element?(view, "#connections-#{connection.id}", "Accra Wholesale")
    assert has_element?(view, "#approve-connection-#{connection.id}")
    assert has_element?(view, "#reject-connection-#{connection.id}")

    view |> element("#approve-connection-#{connection.id}") |> render_click()

    assert has_element?(view, "#connections-#{connection.id}", "Active")
    assert has_element?(view, "#suspend-connection-#{connection.id}")
    assert has_element?(view, "#first-money-step-connected[data-complete='true']")
  end

  test "the tools page carries every section and links back", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#supply-network-tools")
    assert has_element?(view, "#hustle-autopilot")
    assert has_element?(view, "#collaborative-commerce")
    assert has_element?(view, "#opportunity-radar")
    assert has_element?(view, "#earn-catalog")
    assert has_element?(view, "#supplier-inbox")
    assert has_element?(view, "a[href='/admin/settings/supply-network']", "Partners")
  end

  test "a merchant with no store yet gets both pages, not a 500" do
    merchant = create_merchant!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")
    assert has_element?(view, "#partners-stats [data-stat='partners']", "0")

    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network/tools")
    assert has_element?(view, "#supply-network-tools")
  end

  describe "tool pages" do
    @tool_sections %{
      "income-plan" => "#hustle-autopilot",
      "opportunities" => "#opportunity-radar",
      "content-studio" => "#earn-content-studio",
      "commerce-passport" => "#commerce-passport",
      "collaborate" => "#collaborative-commerce",
      "stock-holds" => "#inventory-eligibility",
      "products" => "#earn-catalog",
      "sales-kits" => "#sales-kit-panel",
      "orders" => "#supplier-inbox"
    }

    test "every door opens one tool on its own page", %{conn: conn} do
      for {slug, section} <- @tool_sections do
        {:ok, view, _html} = live(conn, "/admin/settings/supply-network/tools/#{slug}")

        assert has_element?(view, "#supply-tool-#{String.replace(slug, "-", "_")} #{section}"),
               "#{slug} should render #{section}"

        refute has_element?(view, "#supply-network-tools"), "#{slug} is a page, not the workbench"
        assert has_element?(view, "a[href='/admin/settings/supply-network']", "Partners")
      end
    end

    test "the hub's doors point at those pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")

      for slug <- Map.keys(@tool_sections) -- ["products", "sales-kits", "orders"] do
        assert has_element?(
                 view,
                 "#earn-tools a[href^='/admin/settings/supply-network/tools/#{slug}']"
               ),
               "no door for #{slug}"
      end
    end

    test "an unknown tool goes back to the hub", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/settings/supply-network"}}} =
               live(conn, "/admin/settings/supply-network/tools/nope")
    end

    test "the bare tools route is still the whole workbench", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/settings/supply-network/tools")
      assert has_element?(view, "#supply-network-tools #hustle-autopilot")
      assert has_element?(view, "#supply-network-tools #supplier-inbox")
    end
  end
end
