defmodule EmakolaWeb.Storefront.DesignTokensReachStorefrontTest do
  @moduledoc """
  A Design Studio control must change the storefront, not just the preview.

  `EmakolaWeb.Admin.DesignLive` renders its own preview through
  `DesignTokens`, and the storefront renders independently. Nothing tied the
  two together, so controls could — and did — move the preview while leaving
  every real storefront untouched: a merchant saw the change, saved
  successfully, opened their shop and found nothing different.

  These tests assert the storefront end. A token with no test here is a token
  nobody has proven does anything.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  defp store_with(tokens) do
    create_store!(%{
      theme_config: %{"theme" => "starter", "design_tokens" => tokens}
    })
  end

  describe "typography scale" do
    test "compact tightens the whole page", %{conn: conn} do
      store = store_with(%{"typography_scale" => "compact"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "font-size: 93.75%",
             "the compact typography scale never reaches the storefront"
    end

    test "spacious opens it up", %{conn: conn} do
      store = store_with(%{"typography_scale" => "spacious"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "font-size: 112.5%"
    end

    test "the default emits no rule at all", %{conn: conn} do
      store = store_with(%{"typography_scale" => "default"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ ":root { font-size:",
             "an untouched store should keep the browser's own root size"
    end

    test "an unknown value is ignored rather than injected", %{conn: conn} do
      # theme_config is merchant-writable. root_font_size/1 falls through to
      # nil for anything it does not recognise, so junk cannot reach the
      # <style> block.
      store = store_with(%{"typography_scale" => "}; body { display: none } /*"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "display: none"
      refute html =~ ":root { font-size:"
    end
  end

  describe "fonts" do
    test "a heading font choice reaches the storefront", %{conn: conn} do
      store = store_with(%{"heading_font" => "display"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "--dt-heading-font"
      assert html =~ "Playfair Display"
    end
  end
end
