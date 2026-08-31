defmodule EmakolaWeb.OnboardingShopfrontTest do
  @moduledoc """
  Onboarding tells the merchant where they are by showing them their own
  shop being built, not by writing "Step 2 of 4" above four grey bars.

  Merchants on this platform often do not read well, so every one of these
  tests pins a signal that survives without reading: the shop sign carrying
  their name, the shop repainting in the look they picked, their product
  landing on the shelf, and progress shown as marked dots.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.ThemeResolver

  defp sign_in(conn, merchant) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp start_onboarding(conn) do
    merchant = create_merchant!()
    conn = sign_in(conn, merchant)
    {:ok, view, _html} = live(conn, "/onboarding")
    {view, merchant}
  end

  defp preview(view), do: view |> element("#onboarding-shop-preview") |> render()

  describe "the shop preview is the progress indicator" do
    test "the shop sign carries the merchant's name as they type it", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      view |> element("#store-name-form") |> render_change(%{"store_name" => "Kojo Fashion"})

      assert view |> element("#onboarding-shop-sign") |> render() =~ "Kojo Fashion",
             "the merchant typed their shop name and the sign above did not change"
    end

    test "the shop is repainted in the look the merchant picks", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      view |> element("#store-name-form") |> render_change(%{"store_name" => "Repaint Shop"})
      render_click(view, "next_step")

      spotlight = ThemeResolver.theme_module("spotlight").defaults()

      refute preview(view) =~ spotlight.colors.accent,
             "the preview already showed Spotlight's accent before it was picked — " <>
               "this test would pass vacuously"

      view |> element(~s{button[phx-value-theme-id="spotlight"]}) |> render_click()

      assert preview(view) =~ spotlight.colors.accent,
             "Spotlight was picked but the shop preview was not repainted in its tokens"
    end

    test "the first product lands on the shelf as it is named", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      view |> element("#store-name-form") |> render_change(%{"store_name" => "Shelf Shop"})
      render_click(view, "next_step")
      render_click(view, "next_step")

      refute preview(view) =~ "Ankara Dress"

      view |> element("#product-name-form") |> render_change(%{"product_name" => "Ankara Dress"})

      assert view |> element("#onboarding-shelf-hero") |> render() =~ "Ankara Dress",
             "the merchant named their first product and it did not appear in the shop"
    end
  end

  describe "progress needs no reading" do
    test "every step is a dot and exactly one is marked current", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      html = render(view)
      dots = length(String.split(html, ~s(data-onboarding-dot))) - 1

      assert dots == 4, "expected one dot per step, found #{dots}"

      assert length(String.split(html, ~s(aria-current="step"))) - 1 == 1,
             "exactly one dot must be marked as the current step"
    end

    test "the current dot moves with the merchant", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      assert has_element?(view, ~s{[data-onboarding-dot="1"][aria-current="step"]})

      view |> element("#store-name-form") |> render_change(%{"store_name" => "Dot Shop"})
      render_click(view, "next_step")

      assert has_element?(view, ~s{[data-onboarding-dot="2"][aria-current="step"]})
      refute has_element?(view, ~s{[data-onboarding-dot="1"][aria-current="step"]})
    end
  end

  describe "money is picked, not read from a dropdown" do
    test "each currency is its own button carrying its code", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      for code <- ~w(GHS NGN USD) do
        assert has_element?(view, ~s(button[phx-value-currency="#{code}"])),
               "#{code} is not offered as a button a merchant can tap"
      end
    end

    test "tapping a currency re-prices the shop above it", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      assert preview(view) =~ "GH₵120"

      view |> element(~s{button[phx-value-currency="NGN"]}) |> render_click()

      assert preview(view) =~ "₦120"
      refute preview(view) =~ "GH₵120"
    end

    test "the chosen currency is marked pressed, and only that one", %{conn: conn} do
      {view, _merchant} = start_onboarding(conn)

      assert has_element?(view, ~s{button[phx-value-currency="GHS"][aria-pressed="true"]})

      view |> element(~s{button[phx-value-currency="NGN"]}) |> render_click()

      assert has_element?(view, ~s{button[phx-value-currency="NGN"][aria-pressed="true"]})
      refute has_element?(view, ~s{button[phx-value-currency="GHS"][aria-pressed="true"]})
    end
  end
end
