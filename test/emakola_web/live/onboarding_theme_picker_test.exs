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

  describe "storefront previews" do
    test "each offered theme's mock is painted from its own tokens", %{conn: conn} do
      {view, _merchant} = reach_theme_step(conn, "Kente House")
      html = render(view)

      offered = OnboardingLive.offered_theme_ids()

      for id <- offered do
        defaults = ThemeResolver.theme_module(id).defaults()

        assert html =~ defaults.colors.primary,
               "theme #{inspect(id)}'s primary color is not painted in the picker"

        assert html =~ defaults.colors.accent,
               "theme #{inspect(id)}'s accent color is not painted in the picker"

        assert html =~ defaults.fonts.heading,
               "theme #{inspect(id)}'s heading font is not used in its preview"
      end

      # The merchant's own store name is the shop sign in every mock —
      # once per preview, so at least one occurrence per offered theme.
      occurrences = length(String.split(html, "Kente House")) - 1

      assert occurrences >= length(offered),
             "expected the store name in all #{length(offered)} previews, " <>
               "found it #{occurrences} time(s)"
    end

    test "price chips show money from integer minor units, never floats", %{conn: conn} do
      {view, _merchant} = reach_theme_step(conn, "Money Shop")
      html = render(view)

      # 12_000 pesewas → GH₵120 (whole), 8_500 → GH₵85: formatted from
      # integers, so no float artifacts like GH₵120.0 can appear.
      assert html =~ "GH₵120"
      assert html =~ "GH₵85"
      refute html =~ ~r/GH₵\d+\.\d(?!\d)/, "price chip rendered a float artifact"
    end

    test "price chips follow the currency chosen in step 1", %{conn: conn} do
      merchant = create_merchant!()
      conn = sign_in(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")
      render_change(view, "update_store_name", %{"store_name" => "Naira Shop"})
      render_change(view, "update_currency", %{"currency" => "NGN"})
      render_click(view, "next_step")

      html = render(view)
      assert html =~ "₦120"
      refute html =~ "GH₵120"
    end

    test "exactly one card is marked selected via aria-pressed", %{conn: conn} do
      {view, _merchant} = reach_theme_step(conn, "Aria Shop")

      # Market is the default selection.
      assert has_element?(view, ~s{button[phx-value-theme-id="market"][aria-pressed="true"]})
      assert length(String.split(render(view), ~s(aria-pressed="true"))) - 1 == 1

      view
      |> element(~s{button[phx-value-theme-id="spotlight"]})
      |> render_click()

      assert has_element?(view, ~s{button[phx-value-theme-id="spotlight"][aria-pressed="true"]})
      refute has_element?(view, ~s{button[phx-value-theme-id="market"][aria-pressed="true"]})
      assert length(String.split(render(view), ~s(aria-pressed="true"))) - 1 == 1
    end
  end

  describe "save_theme/3" do
    import ExUnit.CaptureLog

    test "a rejected theme write is logged, not swallowed" do
      store = create_store!()
      # A merchant with no membership on the store — the update policy
      # rejects the write, exercising the error branch deterministically.
      stranger = create_merchant!()

      log =
        capture_log(fn ->
          assert {:error, %Emakola.Stores.Store{}} =
                   OnboardingLive.save_theme(store, "atelier", stranger)
        end)

      assert log =~ store.id,
             "the failed theme write did not log the store id — silent in production"

      assert log =~ "atelier"
    end
  end
end
