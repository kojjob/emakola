defmodule Emakola.Themes.LuminousTest do
  @moduledoc """
  Pins the Luminous theme contract — id, name, palette, fonts, defaults,
  section gates, and renderer dispatch — so future palette drift breaks fast.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Luminous

  describe "module metadata" do
    test "id and name are stable" do
      assert Luminous.id() == "luminous"
      assert Luminous.name() == "Luminous"
    end

    test "fonts URL loads Cormorant Garamond + Inter from Google Fonts" do
      [url] = Luminous.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Cormorant+Garamond"
      assert url =~ "Inter"
      assert url =~ "display=swap"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Luminous.defaults()}
    end

    test "exposes id and name", %{defaults: defaults} do
      assert defaults.id == :luminous
      assert defaults.name == "Luminous"
    end

    test "uses rose primary, champagne accent, blush highlight, warm ivory bg",
         %{defaults: defaults} do
      assert defaults.colors.primary == "#DB2777"
      assert defaults.colors.accent == "#E5B299"
      assert defaults.colors.highlight == "#FCE7F3"
      assert defaults.colors.background == "#FFFBF8"
    end

    test "uses Cormorant Garamond heading + Inter body fonts", %{defaults: defaults} do
      assert defaults.fonts.heading == "Cormorant Garamond"
      assert defaults.fonts.body == "Inter"
    end

    test "css_variables map mirrors color and font defaults", %{defaults: defaults} do
      vars = defaults.css_variables
      assert vars["--theme-primary"] == "#DB2777"
      assert vars["--theme-accent"] == "#E5B299"
      assert vars["--theme-highlight"] == "#FCE7F3"
      assert vars["--theme-bg"] == "#FFFBF8"
      assert vars["--theme-font-heading"] =~ "Cormorant Garamond"
      assert vars["--theme-font-body"] =~ "Inter"
    end

    test "section gates include beauty-specific keys", %{defaults: defaults} do
      assert defaults.sections.concerns == true
      assert defaults.sections.bundles == true
      assert defaults.sections.ingredients == true
      assert defaults.sections.stories == true
    end

    test "newsletter is framed as a quiz CTA", %{defaults: defaults} do
      assert defaults.newsletter.title =~ "routine"
      assert defaults.newsletter.button_text =~ "quiz"
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Luminous.renderer(:home) == Emakola.Themes.Luminous.Home
      assert Luminous.renderer(:product_list) == Emakola.Themes.Luminous.ProductList
      assert Luminous.renderer(:product_detail) == Emakola.Themes.Luminous.ProductDetail
      assert Luminous.renderer(:shared) == Emakola.Themes.Luminous.Shared
    end
  end
end
