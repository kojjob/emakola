defmodule Emakola.Themes.ThemeResolverTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "resolve/1" do
    test "empty config returns market defaults" do
      result = ThemeResolver.resolve(%{})

      assert result.theme_id == "market"
      assert result.theme_name == "Market"
      assert result.colors.primary == "#1C1917"
      assert result.colors.accent == "#B45309"
      assert result.colors.background == "#FAFAF9"
      assert result.sections.hero == true
      assert result.sections.categories == true
    end

    test "nil config returns market defaults" do
      result = ThemeResolver.resolve(nil)
      assert result.theme_id == "market"
      assert result.colors.primary == "#1C1917"
    end

    test "atelier theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "atelier"})

      assert result.theme_id == "atelier"
      assert result.theme_name == "Atelier"
      assert result.colors.primary == "#16A34A"
      assert result.colors.accent == "#166534"
      assert result.colors.background == "#FFFFFF"
    end

    test "vibrant theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "vibrant"})

      assert result.theme_id == "vibrant"
      assert result.theme_name == "Vibrant"
      assert result.colors.primary == "#B45309"
      assert result.colors.accent == "#7C2D12"
      assert result.colors.background == "#FFFBEB"
    end

    test "color overrides merge correctly" do
      config = %{
        "theme" => "market",
        "colors" => %{"primary" => "#FF0000", "accent" => "#00FF00"}
      }

      result = ThemeResolver.resolve(config)

      assert result.colors.primary == "#FF0000"
      assert result.colors.accent == "#00FF00"
      # Non-overridden colors keep defaults
      assert result.colors.background == "#FAFAF9"
    end

    test "hero overrides merge correctly" do
      config = %{
        "theme" => "market",
        "hero" => %{"title" => "My Custom Title"}
      }

      result = ThemeResolver.resolve(config)

      assert result.hero.title == "My Custom Title"
      # Non-overridden hero fields keep defaults
      assert result.hero.cta_text == "Shop Now"
    end

    test "section overrides merge correctly" do
      config = %{
        "theme" => "market",
        "sections" => %{"newsletter" => false}
      }

      result = ThemeResolver.resolve(config)

      assert result.sections.newsletter == false
      # Non-overridden sections keep defaults
      assert result.sections.hero == true
      assert result.sections.categories == true
    end

    test "unknown theme falls back to market" do
      result = ThemeResolver.resolve(%{"theme" => "nonexistent"})

      assert result.theme_name == "Market"
      assert result.colors.primary == "#1C1917"
    end

    test "pharmacy theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "pharmacy"})

      assert result.theme_id == "pharmacy"
      assert result.theme_name == "Pharmacy"
      assert result.colors.primary == "#14543E"
      assert result.colors.accent == "#A7E5C5"
      assert result.colors.background == "#F9F6F0"
      assert result.sections.hero == true
      assert result.sections.featured_products == true
      # The trust block ships blank on purpose: it used to certify every store
      # on this theme as a "Licensed pharmacy" selling "Genuine medicines". The
      # KEY must survive resolution (deep_merge_atomize/2 discards overrides for
      # keys absent from the defaults), but the platform states nothing in it.
      assert Map.has_key?(result, :trust)
      assert result.trust.title == nil
      assert result.trust.items == []
    end

    test "beauty theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "beauty"})

      assert result.theme_id == "beauty"
      assert result.theme_name == "Beauty"
      assert result.colors.primary == "#6B4423"
      assert result.colors.accent == "#C9925E"
      assert result.colors.background == "#F5EFE5"
      assert result.sections.hero == true
      assert result.sections.featured_products == true
    end

    test "home_living theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "home_living"})

      assert result.theme_id == "home_living"
      assert result.theme_name == "Home Living"
      assert result.colors.primary == "#1F2937"
      assert result.colors.accent == "#84CC16"
      assert result.colors.background == "#FAF7F2"
      assert result.sections.hero == true
      assert result.sections.featured_products == true
    end

    test "electronics theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "electronics"})

      assert result.theme_id == "electronics"
      assert result.theme_name == "Electronics"
      assert result.colors.primary == "#134E4A"
      assert result.colors.accent == "#0EA5E9"
      assert result.colors.background == "#F5EFE5"
      assert result.sections.hero == true
      assert result.sections.featured_products == true
    end

    test "fashion theme returns correct defaults" do
      result = ThemeResolver.resolve(%{"theme" => "fashion"})

      assert result.theme_id == "fashion"
      assert result.theme_name == "Fashion"
      assert result.colors.primary == "#5B21B6"
      assert result.colors.accent == "#D97706"
      assert result.colors.background == "#FAF6EE"
      assert result.sections.hero == true
      assert result.sections.featured_products == true
    end
  end

  describe "theme-specific config sections" do
    test "pharmacy stats reach the resolved theme" do
      result = ThemeResolver.resolve(%{"theme" => "pharmacy"})

      assert result.stats.heading =~ "Healthcare"
      assert is_list(result.stats.items)
    end

    test "merchant overrides merge into theme-specific sections" do
      result =
        ThemeResolver.resolve(%{
          "theme" => "pharmacy",
          "stats" => %{"heading" => "Our numbers"}
        })

      assert result.stats.heading == "Our numbers"
      # non-overridden fields keep their defaults
      assert is_list(result.stats.items)
    end

    test "home_living rooms and feature_tiles pass through; sale_band invents no delivery tile" do
      result = ThemeResolver.resolve(%{"theme" => "home_living"})

      assert result.rooms.title == "Shop by room"
      assert is_list(result.feature_tiles.items)

      # sale_band used to ship `items` containing "Free Delivery — On orders GHS
      # 500+", so every Home Living store made a promise its merchant never had.
      # It ships an EMPTY list now: the section builds the delivery tile from the
      # store's own delivery zones and omits it entirely when there are none. The
      # key itself must survive — deep_merge_atomize/2 drops overrides whose key
      # is absent from the defaults, so a merchant's own items depend on it.
      assert result.sale_band.items == []
    end

    test "a merchant's own sale_band items still pass through" do
      items = [%{"icon" => "bolt", "title" => "Same-week build", "subtitle" => "Made to order"}]

      result =
        ThemeResolver.resolve(%{"theme" => "home_living", "sale_band" => %{"items" => items}})

      assert is_list(result.sale_band.items)
    end

    test "unknown config keys never leak into the resolved theme" do
      result = ThemeResolver.resolve(%{"theme" => "market", "hax" => %{"a" => 1}})

      refute Map.has_key?(result, :hax)
    end

    test "theme identity keys are not merchant-overridable" do
      result =
        ThemeResolver.resolve(%{
          "theme" => "pharmacy",
          "css_variables" => %{"--theme-primary" => "evil"},
          "name" => "Spoofed"
        })

      assert result.theme_name == "Pharmacy"
      refute Map.get(result, :css_variables, %{})["--theme-primary"] == "evil"
    end
  end

  describe "offerable_theme_ids/0" do
    test "offerable = every registered theme (no themes are currently culled)" do
      assert ThemeResolver.offerable_theme_ids() == ThemeResolver.theme_ids()
    end

    test "spotlight and market are offerable" do
      offerable = ThemeResolver.offerable_theme_ids()

      assert "spotlight" in offerable
      assert "market" in offerable
    end
  end

  describe "theme_module/1" do
    test "returns Atelier module for atelier" do
      assert ThemeResolver.theme_module("atelier") == Emakola.Themes.Atelier
    end

    test "returns Market module for market" do
      assert ThemeResolver.theme_module("market") == Emakola.Themes.Market
    end

    test "returns Vibrant module for vibrant" do
      assert ThemeResolver.theme_module("vibrant") == Emakola.Themes.Vibrant
    end

    test "returns Market module for unknown theme" do
      assert ThemeResolver.theme_module("unknown") == Emakola.Themes.Market
    end

    test "returns Pharmacy module for pharmacy" do
      assert ThemeResolver.theme_module("pharmacy") == Emakola.Themes.Pharmacy
    end

    test "returns Beauty module for beauty" do
      assert ThemeResolver.theme_module("beauty") == Emakola.Themes.Beauty
    end

    test "returns HomeLiving module for home_living" do
      assert ThemeResolver.theme_module("home_living") == Emakola.Themes.HomeLiving
    end

    test "returns Electronics module for electronics" do
      assert ThemeResolver.theme_module("electronics") == Emakola.Themes.Electronics
    end

    test "returns Fashion module for fashion" do
      assert ThemeResolver.theme_module("fashion") == Emakola.Themes.Fashion
    end
  end
end
