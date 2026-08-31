defmodule EmakolaWeb.OnboardingBuyerProtectionTest do
  @moduledoc """
  Buyer protection was opt-in and 1 of 9 production stores had opted in — not
  because merchants weighed it and declined, but because nothing ever asked.

  Turning it on by default was rejected deliberately: it makes Makola custodian
  of the merchant's money between sale and delivery (OrderSettlement returns
  {:hold, :buyer_protection}, which attaches no gateway share at all). So the
  fix is to ask, on the last onboarding screen, in one short question.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  # A merchant with NO store — setup_authenticated_merchant/1 creates one, and
  # onboarding redirects anyone who already finished it.
  setup %{conn: conn} do
    merchant = create_merchant!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {:ok, conn: conn, merchant: merchant}
  end

  test "the final onboarding step asks about holding payment", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/onboarding")

    # Walk to the final screen the way a merchant does — there is no
    # jump-to-step event.
    render_change(view, "update_store_name", %{"store_name" => "Kwame Shop"})
    render_click(view, "next_step", %{})
    render_click(view, "skip_step", %{})
    html = render_click(view, "skip_step", %{})

    assert html =~ "Hold money till delivery"
  end

  test "the question defaults to off, matching the store default", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/onboarding")

    render_change(view, "update_store_name", %{"store_name" => "Kwame Shop"})
    render_click(view, "next_step", %{})
    render_click(view, "skip_step", %{})
    html = render_click(view, "skip_step", %{})

    refute html =~ ~s(name="buyer_protection" checked)
  end
end
