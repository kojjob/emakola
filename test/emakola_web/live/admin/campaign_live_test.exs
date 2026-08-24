defmodule EmakolaWeb.Admin.CampaignLiveTest do
  @moduledoc """
  The previous suite here asserted the fabrication itself — "displays campaign
  cards with sample data", "displays campaign stats in cards" — so it was
  deleted with the invented data it pinned. A test that guards a lie is worse
  than no test: it makes removing the lie look like a regression.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    {merchant, _store} = Factory.create_merchant_with_store!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn}
  end

  test "shows an empty state, and claims nothing was sent", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

    assert html =~ "Campaigns"
    assert html =~ "No campaigns yet"

    # The figures that used to be here described nobody's shop, and two of
    # them are not measurable on either channel without provider webhooks.
    refute html =~ "Welcome Series"
    refute html =~ "Abandoned Cart Recovery"
    refute html =~ "Opened"
    refute html =~ "Clicked"
  end

  test "offers no control that does not work yet", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

    # Create/delete flashed success and saved nothing. Until the engine lands
    # the page carries no button at all, rather than a button that lies.
    refute has_element?(view, "[phx-submit='save_campaign']")
    refute has_element?(view, "[phx-click='delete_campaign']")
    refute has_element?(view, "[phx-click='use_template']")
  end
end
