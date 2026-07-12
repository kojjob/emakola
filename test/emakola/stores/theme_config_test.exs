defmodule Emakola.Stores.ThemeConfigTest do
  use ExUnit.Case, async: true

  alias Emakola.Stores.ThemeConfig

  describe "validate/1" do
    test "valid full config returns :ok" do
      config = %{
        "theme" => "atelier",
        "colors" => %{
          "primary" => "#CA8A04",
          "secondary" => "#F5F5DC",
          "accent" => "#D4AF37",
          "background" => "#FAFAF9",
          "text" => "#0F172A"
        },
        "hero" => %{
          "title" => "Welcome",
          "subtitle" => "Shop our collection",
          "image_url" => "https://example.com/hero.jpg"
        },
        "sections" => %{
          "show_featured" => true,
          "show_categories" => true,
          "show_about" => false
        }
      }

      assert :ok = ThemeConfig.validate(config)
    end

    test "empty config is valid" do
      assert :ok = ThemeConfig.validate(%{})
    end

    test "partial config with only theme is valid" do
      assert :ok = ThemeConfig.validate(%{"theme" => "market"})
    end

    test "partial config with only colors is valid" do
      assert :ok = ThemeConfig.validate(%{"colors" => %{"primary" => "#2563EB"}})
    end

    test "partial config with only sections is valid" do
      assert :ok = ThemeConfig.validate(%{"sections" => %{"show_featured" => true}})
    end

    test "every offerable theme validates — the allowlist cannot drift" do
      offerable = Emakola.Themes.ThemeResolver.offerable_theme_ids()
      refute Enum.empty?(offerable), "no offerable themes — this test would be vacuous"

      # Spotlight is the theme the old hardcoded list silently dropped.
      assert "spotlight" in offerable

      for theme <- offerable do
        assert :ok = ThemeConfig.validate(%{"theme" => theme}),
               "offerable theme #{inspect(theme)} is rejected by ThemeConfig.validate/1"
      end
    end

    test "invalid theme name returns error" do
      assert {:error, msg} = ThemeConfig.validate(%{"theme" => "neon"})
      assert msg =~ "invalid theme name"
    end

    test "invalid hex color returns error" do
      config = %{"colors" => %{"primary" => "not-a-color"}}
      assert {:error, msg} = ThemeConfig.validate(config)
      assert msg =~ "invalid hex color"
    end

    test "hex color without hash returns error" do
      config = %{"colors" => %{"primary" => "CA8A04"}}
      assert {:error, msg} = ThemeConfig.validate(config)
      assert msg =~ "invalid hex color"
    end

    test "short hex color returns error" do
      config = %{"colors" => %{"primary" => "#FFF"}}
      assert {:error, msg} = ThemeConfig.validate(config)
      assert msg =~ "invalid hex color"
    end

    test "invalid section value returns error" do
      config = %{"sections" => %{"show_featured" => "yes"}}
      assert {:error, msg} = ThemeConfig.validate(config)
      assert msg =~ "must be a boolean"
    end

    test "non-map input returns error" do
      assert {:error, msg} = ThemeConfig.validate("not a map")
      assert msg =~ "must be a map"
    end
  end
end
