defmodule EmakolaWeb.OnboardingThemeTest do
  @moduledoc """
  Onboarding already has a theme picker (step 2). These tests pin down whether
  the merchant's choice actually survives store creation.

  `maybe_save_theme/2` swallows its own failure (`{:error, _} -> store`), so a
  rejected write leaves the store with no theme at all — it silently falls
  through to `@default_theme` ("market"). In production, 4 of 9 stores have no
  theme key, which is exactly what that failure mode would look like.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp sign_in(conn, merchant) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
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

  test "a theme picked during onboarding is persisted on the new store", %{conn: conn} do
    merchant = create_merchant!()
    conn = sign_in(conn, merchant)

    {:ok, view, _html} = live(conn, "/onboarding")

    # Step 1 — name the store.
    render_change(view, "update_store_name", %{"store_name" => "Kente House"})
    render_click(view, "next_step")

    # Step 2 — the theme picker. Choose something that is NOT the default,
    # so a pass here cannot be explained by the "market" fallback.
    render_click(view, "select_theme", %{"theme-id" => "atelier"})
    render_click(view, "next_step")

    # Step 3 — skip the first product.
    render_click(view, "skip_step")

    # Step 4 — finish.
    render_click(view, "complete")

    store = store_for(merchant)
    assert store, "onboarding did not create a store"

    assert store.theme_config["theme"] == "atelier",
           "the merchant picked Atelier but the store persisted " <>
             inspect(store.theme_config["theme"]) <>
             " — maybe_save_theme/2 swallows its failure, so the choice is lost silently."
  end

  test "a merchant who never touches the picker still gets an explicit theme", %{conn: conn} do
    merchant = create_merchant!()
    conn = sign_in(conn, merchant)

    {:ok, view, _html} = live(conn, "/onboarding")

    render_change(view, "update_store_name", %{"store_name" => "Default Shop"})
    render_click(view, "next_step")
    # Straight past the picker without clicking a card.
    render_click(view, "next_step")
    render_click(view, "skip_step")
    render_click(view, "complete")

    store = store_for(merchant)

    assert store.theme_config["theme"] == "market",
           "a store should carry an explicit theme even when the merchant accepts the " <>
             "default — a missing key means the write was dropped, not that they chose Market."
  end
end
