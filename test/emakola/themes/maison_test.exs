defmodule Emakola.Themes.MaisonTest do
  @moduledoc """
  Pins the Maison theme contract — id, name, palette, fonts, defaults,
  section gates, and renderer dispatch — so future palette drift breaks fast.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Maison

  describe "module metadata" do
    test "id and name are stable" do
      assert Maison.id() == "maison"
      assert Maison.name() == "Maison"
    end

    test "fonts URL loads Playfair Display + Inter from Google Fonts" do
      [url] = Maison.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Playfair+Display"
      assert url =~ "Inter"
      assert url =~ "display=swap"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Maison.defaults()}
    end

    test "exposes id and name", %{defaults: defaults} do
      assert defaults.id == :maison
      assert defaults.name == "Maison"
    end

    test "uses stone-900 primary, gold accent, warm gray highlight, white bg",
         %{defaults: defaults} do
      assert defaults.colors.primary == "#1C1917"
      assert defaults.colors.accent == "#D4A843"
      assert defaults.colors.highlight == "#F5F5F4"
      assert defaults.colors.background == "#FFFFFF"
    end

    test "uses Playfair Display heading + Inter body fonts", %{defaults: defaults} do
      assert defaults.fonts.heading == "Playfair Display"
      assert defaults.fonts.body == "Inter"
    end

    test "css_variables map mirrors color and font defaults", %{defaults: defaults} do
      vars = defaults.css_variables
      assert vars["--theme-primary"] == "#1C1917"
      assert vars["--theme-accent"] == "#D4A843"
      assert vars["--theme-highlight"] == "#F5F5F4"
      assert vars["--theme-bg"] == "#FFFFFF"
      assert vars["--theme-font-heading"] =~ "Playfair Display"
      assert vars["--theme-font-body"] =~ "Inter"
    end

    test "section gates include editorial-specific keys", %{defaults: defaults} do
      assert defaults.sections.lookbook == true
      assert defaults.sections.capsules == true
      assert defaults.sections.designer_note == true
      # Film embed defaults to off — opt-in due to bandwidth cost
      assert defaults.sections.film == false
    end

    test "newsletter is framed as a private list", %{defaults: defaults} do
      assert defaults.newsletter.title =~ "Private"
    end

    test "hero defaults are editorial — collection name + season", %{defaults: defaults} do
      assert defaults.hero.title =~ "Edit"
      assert defaults.hero.subtitle =~ "2026"
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Maison.renderer(:home) == Emakola.Themes.Maison.Home
      assert Maison.renderer(:product_list) == Emakola.Themes.Maison.ProductList
      assert Maison.renderer(:product_detail) == Emakola.Themes.Maison.ProductDetail
      assert Maison.renderer(:shared) == Emakola.Themes.Maison.Shared
    end
  end
end
