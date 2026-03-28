defmodule Emakola.Themes.DesignTokensTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.DesignTokens

  describe "resolve/1" do
    test "returns defaults when nil" do
      tokens = DesignTokens.resolve(nil)
      assert tokens.button_style == "rounded"
      assert tokens.card_style == "shadow"
      assert tokens.product_grid_columns == 3
    end

    test "merges overrides into defaults" do
      tokens = DesignTokens.resolve(%{"button_style" => "pill", "card_style" => "bordered"})
      assert tokens.button_style == "pill"
      assert tokens.card_style == "bordered"
      assert tokens.navbar_layout == "left"
    end

    test "ignores unknown keys" do
      tokens = DesignTokens.resolve(%{"unknown_key" => "value"})
      assert tokens == DesignTokens.defaults()
    end
  end

  describe "button_classes/1" do
    test "pill" do
      assert DesignTokens.button_classes("pill") == "rounded-full"
    end

    test "square" do
      assert DesignTokens.button_classes("square") == "rounded-none"
    end

    test "rounded (default)" do
      assert DesignTokens.button_classes("rounded") == "rounded-lg"
    end
  end

  describe "card_classes/1" do
    test "minimal" do
      assert DesignTokens.card_classes("minimal") == "bg-white"
    end

    test "shadow" do
      assert DesignTokens.card_classes("shadow") =~ "shadow"
    end

    test "bordered" do
      assert DesignTokens.card_classes("bordered") =~ "border"
    end
  end

  describe "grid_classes/1" do
    test "2 columns" do
      assert DesignTokens.grid_classes(2) =~ "sm:grid-cols-2"
      refute DesignTokens.grid_classes(2) =~ "lg:grid-cols"
    end

    test "3 columns" do
      assert DesignTokens.grid_classes(3) =~ "lg:grid-cols-3"
    end

    test "4 columns" do
      assert DesignTokens.grid_classes(4) =~ "lg:grid-cols-4"
    end

    test "accepts string values" do
      assert DesignTokens.grid_classes("3") == DesignTokens.grid_classes(3)
    end
  end

  describe "heading_font_family/1" do
    test "serif returns Cormorant" do
      assert DesignTokens.heading_font_family("serif") =~ "Cormorant"
    end

    test "display returns Playfair" do
      assert DesignTokens.heading_font_family("display") =~ "Playfair"
    end

    test "sans returns inherit" do
      assert DesignTokens.heading_font_family("sans") == "inherit"
    end
  end

  describe "heading_font_url/1" do
    test "serif returns Google Fonts URL" do
      assert DesignTokens.heading_font_url("serif") =~ "fonts.googleapis.com"
    end

    test "sans returns nil" do
      assert DesignTokens.heading_font_url("sans") == nil
    end
  end

  describe "options/0" do
    test "returns options for all 10 token dimensions" do
      opts = DesignTokens.options()
      assert map_size(opts) == 10
      assert Map.has_key?(opts, :button_style)
      assert Map.has_key?(opts, :heading_font)
    end

    test "each option has value, label, and icon" do
      for {_key, options} <- DesignTokens.options() do
        for opt <- options do
          assert Map.has_key?(opt, :value)
          assert Map.has_key?(opt, :label)
          assert Map.has_key?(opt, :icon)
        end
      end
    end
  end
end
