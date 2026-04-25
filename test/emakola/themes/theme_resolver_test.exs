defmodule Emakola.Themes.ThemeResolverTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "resolve/1" do
    test "empty config returns market defaults" do
      result = ThemeResolver.resolve(%{})

      assert result.theme_id == "market"
      assert result.theme_name == "Market"
      assert result.colors.primary == "#2563EB"
      assert result.colors.accent == "#0F172A"
      assert result.colors.background == "#FFFFFF"
      assert result.sections.hero == true
      assert result.sections.categories == true
    end

    test "nil config returns market defaults" do
      result = ThemeResolver.resolve(nil)
      assert result.theme_id == "market"
      assert result.colors.primary == "#2563EB"
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

    test "savor theme returns correct defaults (food & drink niche)" do
      result = ThemeResolver.resolve(%{"theme" => "savor"})

      assert result.theme_id == "savor"
      assert result.theme_name == "Savor"
      assert result.colors.primary == "#DC2626"
      assert result.colors.accent == "#15803D"
      assert result.colors.background == "#FFFBEB"
      assert result.fonts.heading == "Anton"
      assert result.fonts.body == "Lora"
      # Restaurant-specific section gates
      assert result.sections.menu == true
      assert result.sections.delivery == true
    end

    test "luminous theme returns correct defaults (beauty & cosmetics niche)" do
      result = ThemeResolver.resolve(%{"theme" => "luminous"})

      assert result.theme_id == "luminous"
      assert result.theme_name == "Luminous"
      assert result.colors.primary == "#DB2777"
      assert result.colors.accent == "#E5B299"
      assert result.colors.background == "#FFFBF8"
      assert result.fonts.heading == "Cormorant Garamond"
      assert result.fonts.body == "Inter"
      # Beauty-specific section gates
      assert result.sections.concerns == true
      assert result.sections.bundles == true
      assert result.sections.ingredients == true
    end

    test "maison theme returns correct defaults (premium fashion niche)" do
      result = ThemeResolver.resolve(%{"theme" => "maison"})

      assert result.theme_id == "maison"
      assert result.theme_name == "Maison"
      assert result.colors.primary == "#1C1917"
      assert result.colors.accent == "#D4A843"
      assert result.colors.background == "#FFFFFF"
      assert result.fonts.heading == "Playfair Display"
      assert result.fonts.body == "Inter"
      # Editorial-specific section gates
      assert result.sections.lookbook == true
      assert result.sections.capsules == true
      assert result.sections.designer_note == true
    end

    test "heritage theme returns correct defaults (lifestyle / crafts niche)" do
      result = ThemeResolver.resolve(%{"theme" => "heritage"})

      assert result.theme_id == "heritage"
      assert result.theme_name == "Heritage"
      assert result.colors.primary == "#A0522D"
      assert result.colors.accent == "#84A98C"
      assert result.colors.background == "#FFFBEB"
      assert result.fonts.heading == "Lora"
      assert result.fonts.body == "Inter"
      # Lifestyle/crafts-specific section gates
      assert result.sections.makers == true
      assert result.sections.rooms == true
      assert result.sections.story == true
      assert result.sections.bundles == true
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
      assert result.colors.background == "#FFFFFF"
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
      assert result.colors.primary == "#2563EB"
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
  end
end
