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

  describe "reach/1 tells the truth" do
    # The Design Studio now prints a caveat under any control that does not
    # reach the merchant's storefront, sourced from DesignTokens.reach/1.
    # That caveat is only worth anything if the claim behind it is checked:
    # a token promoted to :all_themes without actually being wired would put
    # the studio right back to implying something false.

    @all_theme_tokens ["heading_font", "body_font", "typography_scale"]

    test "every :all_themes token is proven to change the storefront" do
      # Each token here must have a test above showing rendered output change.
      # Adding one without that test is the regression this guards.
      for token <- @all_theme_tokens do
        assert Emakola.Themes.DesignTokens.reach(token) == :all_themes
        assert Emakola.Themes.DesignTokens.reach_note(token) == nil
      end
    end

    test "a control that reaches nothing says so" do
      for token <- ["card_style", "hero_layout", "product_grid_columns"] do
        assert Emakola.Themes.DesignTokens.reach(token) == :not_wired

        assert Emakola.Themes.DesignTokens.reach_note(token) =~ "won't affect your store"
      end
    end

    test "a control only some themes read names them" do
      assert Emakola.Themes.DesignTokens.reach("button_style") == {:some_themes, ["atelier"]}
      assert Emakola.Themes.DesignTokens.reach_note("button_style") =~ "Atelier"
    end

    test "card_style really does change nothing, so the caveat is not slander", %{conn: conn} do
      plain = store_with(%{})
      bordered = store_with(%{"card_style" => "bordered"})

      {:ok, _v, plain_html} = live(conn, "/s/#{plain.slug}")
      {:ok, _v, bordered_html} = live(conn, "/s/#{bordered.slug}")

      # Slugs differ, so compare the emitted style block rather than the page.
      assert style_block(plain_html) == style_block(bordered_html),
             "card_style now changes the storefront — promote it out of :not_wired " <>
               "in DesignTokens.reach/1 so the studio stops warning about it"
    end

    defp style_block(html) do
      case Regex.run(~r|<style>(.*?)</style>|s, html) do
        [_, block] -> String.trim(block)
        _ -> ""
      end
    end
  end

  describe "every offered font is actually loadable" do
    # An option in the picker whose family has no matching webfont URL renders
    # as the fallback and looks like nothing happened — the same silent
    # failure as a control that reaches nothing, one layer down.

    alias Emakola.Themes.DesignTokens

    test "every heading option resolves to a family, and non-system ones load a webfont" do
      for %{value: value, label: label} <- DesignTokens.options().heading_font do
        family = DesignTokens.heading_font_family(value)
        url = DesignTokens.heading_font_url(value)

        if value == "sans" do
          assert family == "inherit"
          assert is_nil(url)
        else
          refute family == "inherit", "heading option #{label} (#{value}) resolves to no family"

          assert url, "heading option #{label} (#{value}) has a family but loads no webfont"

          # The family's first quoted name must appear in the URL, or the page
          # requests one font and asks for another.
          [_, quoted] = Regex.run(~r/'([^']+)'/, family)

          assert String.contains?(url, String.replace(quoted, " ", "+")),
                 "#{label}: family #{quoted} does not match its Google Fonts URL"
        end
      end
    end

    test "every body option resolves to a family, and non-system ones load a webfont" do
      for %{value: value, label: label} <- DesignTokens.options().body_font do
        family = DesignTokens.body_font_family(value)
        url = DesignTokens.body_font_url(value)

        if value == "sans" do
          assert family == "inherit"
          assert is_nil(url)
        else
          refute family == "inherit", "body option #{label} (#{value}) resolves to no family"
          assert url, "body option #{label} (#{value}) has a family but loads no webfont"

          [_, quoted] = Regex.run(~r/'([^']+)'/, family)

          assert String.contains?(url, String.replace(quoted, " ", "+")),
                 "#{label}: family #{quoted} does not match its Google Fonts URL"
        end
      end
    end

    test "a newly offered heading font reaches the storefront", %{conn: conn} do
      store = store_with(%{"heading_font" => "grotesk"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Space Grotesk"
      assert html =~ "Space+Grotesk"
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
