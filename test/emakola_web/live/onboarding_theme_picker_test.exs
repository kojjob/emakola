defmodule EmakolaWeb.OnboardingThemePickerTest do
  @moduledoc """
  The onboarding theme picker (step 2) must offer every registered theme
  unless it is explicitly excluded, must reject crafted theme ids, and must
  show each theme as a miniature storefront painted from its own tokens.

  The coverage guard here is the point: a theme added to ThemeResolver that
  is neither described in the picker nor explicitly excluded fails loudly
  instead of silently vanishing from onboarding (as Spotlight did).
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.ThemeResolver
  alias EmakolaWeb.OnboardingLive

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

  # Mounts onboarding and advances to step 2 (the theme picker).
  # Onboarding always precedes products, so the picker inherently renders
  # against a store with no catalog at all.
  defp reach_theme_step(conn, store_name) do
    merchant = create_merchant!()
    conn = sign_in(conn, merchant)

    {:ok, view, _html} = live(conn, "/onboarding")
    render_change(view, "update_store_name", %{"store_name" => store_name})
    render_click(view, "next_step")

    {view, merchant}
  end

  defp finish_onboarding(view) do
    render_click(view, "next_step")
    render_click(view, "skip_step")
    render_click(view, "complete")
  end

  describe "theme coverage" do
    test "every registered theme is offered unless explicitly excluded", %{conn: conn} do
      registered = ThemeResolver.theme_ids()
      excluded = OnboardingLive.excluded_theme_ids()

      assert excluded -- registered == [],
             "excluded_theme_ids/0 lists ids not registered in ThemeResolver: " <>
               inspect(excluded -- registered)

      {view, _merchant} = reach_theme_step(conn, "Coverage Shop")
      html = render(view)

      for id <- registered -- excluded do
        assert html =~ ~s(phx-value-theme-id="#{id}"),
               "theme #{inspect(id)} is registered in ThemeResolver but the onboarding " <>
                 "picker does not offer it — describe it in OnboardingLive or add it to " <>
                 "the explicit exclusion list"
      end

      for id <- excluded do
        refute html =~ ~s(phx-value-theme-id="#{id}"),
               "theme #{inspect(id)} is explicitly excluded but still rendered in the picker"
      end
    end

    test "spotlight is offered and persists when picked", %{conn: conn} do
      {view, merchant} = reach_theme_step(conn, "Spotlight Shop")

      view
      |> element(~s{button[phx-value-theme-id="spotlight"]})
      |> render_click()

      finish_onboarding(view)

      store = store_for(merchant)
      assert store, "onboarding did not create a store"

      assert store.theme_config["theme"] == "spotlight",
             "Spotlight was picked but the store persisted " <>
               inspect(store.theme_config["theme"])
    end
  end

  describe "crafted theme ids" do
    test "an unregistered theme-id is ignored, not persisted", %{conn: conn} do
      {view, merchant} = reach_theme_step(conn, "Crafted Shop")

      before_html = render(view)
      render_click(view, "select_theme", %{"theme-id" => "totally-fake"})

      assert render(view) == before_html,
             "a crafted theme-id changed the picker state"

      finish_onboarding(view)
      store = store_for(merchant)

      assert store.theme_config["theme"] == "market",
             "a crafted theme-id was written to the store: " <>
               inspect(store.theme_config["theme"])
    end

    test "a registered but excluded theme-id is ignored, not persisted", %{conn: conn} do
      {view, merchant} = reach_theme_step(conn, "Excluded Shop")

      # "akoma" exists in ThemeResolver but is deliberately not offered —
      # a crafted event must not smuggle it past the picker.
      render_click(view, "select_theme", %{"theme-id" => "akoma"})
      finish_onboarding(view)

      store = store_for(merchant)

      assert store.theme_config["theme"] == "market",
             "an excluded theme-id was written to the store: " <>
               inspect(store.theme_config["theme"])
    end
  end
end
