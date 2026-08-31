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

  defp store_for(merchant) do
    Emakola.Stores.Store
    |> Ash.read!(authorize?: false)
    |> Enum.find(fn store ->
      Emakola.Accounts.StoreMembership
      |> Ash.read!(authorize?: false)
      |> Enum.any?(&(&1.store_id == store.id and &1.merchant_id == merchant.id))
    end)
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

  test "the answer the merchant gives is the one the store is created with", %{
    conn: conn,
    merchant: merchant
  } do
    # The question is asked on the last screen, but the store is written on
    # the way in to it. If the answer is not applied after it is given, the
    # whole point of asking — 1 of 9 stores had protection on because
    # nothing ever raised it — is lost, silently.
    {:ok, view, _html} = live(conn, ~p"/onboarding")

    render_change(view, "update_store_name", %{"store_name" => "Protected Shop"})
    render_click(view, "next_step", %{})
    render_click(view, "skip_step", %{})

    render_click(view, "toggle_buyer_protection", %{})
    render_click(view, "complete", %{})

    store = store_for(merchant)
    assert store, "onboarding did not create a store"

    assert store.buyer_protection_enabled,
           "the merchant switched buyer protection on and the store was saved without it"
  end
end
