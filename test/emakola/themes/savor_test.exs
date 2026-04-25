defmodule Emakola.Themes.SavorTest do
  @moduledoc """
  Pins the Savor theme contract — id, name, palette, fonts, defaults,
  and renderer dispatch — so future palette drift breaks fast.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Savor

  describe "module metadata" do
    test "id and name are stable" do
      assert Savor.id() == "savor"
      assert Savor.name() == "Savor"
    end

    test "fonts URL loads Anton + Lora from Google Fonts" do
      [url] = Savor.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Anton"
      assert url =~ "Lora"
      assert url =~ "display=swap"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Savor.defaults()}
    end

    test "exposes id and name", %{defaults: defaults} do
      assert defaults.id == :savor
      assert defaults.name == "Savor"
    end

    test "uses tomato red primary, olive accent, butter highlight, cream bg", %{
      defaults: defaults
    } do
      assert defaults.colors.primary == "#DC2626"
      assert defaults.colors.accent == "#15803D"
      assert defaults.colors.highlight == "#FEF3C7"
      assert defaults.colors.background == "#FFFBEB"
    end

    test "uses Anton heading + Lora body fonts", %{defaults: defaults} do
      assert defaults.fonts.heading == "Anton"
      assert defaults.fonts.body == "Lora"
    end

    test "css_variables map mirrors color and font defaults", %{defaults: defaults} do
      vars = defaults.css_variables
      assert vars["--theme-primary"] == "#DC2626"
      assert vars["--theme-accent"] == "#15803D"
      assert vars["--theme-highlight"] == "#FEF3C7"
      assert vars["--theme-bg"] == "#FFFBEB"
      assert vars["--theme-font-heading"] =~ "Anton"
      assert vars["--theme-font-body"] =~ "Lora"
    end

    test "section gates include restaurant-specific keys", %{defaults: defaults} do
      assert defaults.sections.menu == true
      assert defaults.sections.delivery == true
      assert defaults.sections.favorites == true
      assert defaults.sections.story == true
    end

    test "hero defaults are appetite-focused", %{defaults: defaults} do
      assert defaults.hero.title == "Hot from the kitchen"
      assert defaults.hero.cta_text == "Order now"
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Savor.renderer(:home) == Emakola.Themes.Savor.Home
      assert Savor.renderer(:product_list) == Emakola.Themes.Savor.ProductList
      assert Savor.renderer(:product_detail) == Emakola.Themes.Savor.ProductDetail
      assert Savor.renderer(:shared) == Emakola.Themes.Savor.Shared
    end
  end
end
