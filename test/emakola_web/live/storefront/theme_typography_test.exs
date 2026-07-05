defmodule EmakolaWeb.Storefront.ThemeTypographyTest do
  @moduledoc """
  The storefront layout's design-token font rules must not override theme
  typography unless the merchant explicitly picked a font token.

  Regression: the layout unconditionally emitted
  `h1..h6 { font-family: var(--dt-heading-font) !important; }` with the
  default token resolving to the CSS-wide keyword `inherit` — an invalid
  custom-property value — so the !important rule beat every theme's heading
  class in both token states and no theme heading font ever rendered.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @heading_override "font-family: var(--dt-heading-font) !important"
  @body_override "font-family: var(--dt-body-font)"

  describe "with default design tokens (no merchant font pick)" do
    test "layout emits no heading-font override, so theme fonts win", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "beauty"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ @heading_override
      refute html =~ @body_override
    end
  end

  describe "with an explicit merchant font pick" do
    test "layout emits the heading override with the chosen font", %{conn: conn} do
      store =
        Factory.create_store!(%{
          theme_config: %{
            "theme" => "beauty",
            "design_tokens" => %{"heading_font" => "display"}
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ @heading_override
      assert html =~ "Playfair Display"
    end

    test "layout emits the body override with the chosen font", %{conn: conn} do
      store =
        Factory.create_store!(%{
          theme_config: %{
            "theme" => "beauty",
            "design_tokens" => %{"body_font" => "serif"}
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ @body_override
      assert html =~ "Lora"
    end
  end
end
