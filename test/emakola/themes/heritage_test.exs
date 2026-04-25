defmodule Emakola.Themes.HeritageTest do
  @moduledoc """
  Pins the Heritage theme contract — id, name, palette, fonts, defaults,
  section gates, and renderer dispatch.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Heritage

  describe "module metadata" do
    test "id and name are stable" do
      assert Heritage.id() == "heritage"
      assert Heritage.name() == "Heritage"
    end

    test "fonts URL loads Lora + Inter from Google Fonts" do
      [url] = Heritage.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Lora"
      assert url =~ "Inter"
      assert url =~ "display=swap"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Heritage.defaults()}
    end

    test "exposes id and name", %{defaults: defaults} do
      assert defaults.id == :heritage
      assert defaults.name == "Heritage"
    end

    test "uses clay primary, sage accent, raw cream highlight, warm ivory bg",
         %{defaults: defaults} do
      assert defaults.colors.primary == "#A0522D"
      assert defaults.colors.accent == "#84A98C"
      assert defaults.colors.highlight == "#F4E4C1"
      assert defaults.colors.background == "#FFFBEB"
    end

    test "uses Lora heading + Inter body fonts", %{defaults: defaults} do
      assert defaults.fonts.heading == "Lora"
      assert defaults.fonts.body == "Inter"
    end

    test "css_variables map mirrors color and font defaults", %{defaults: defaults} do
      vars = defaults.css_variables
      assert vars["--theme-primary"] == "#A0522D"
      assert vars["--theme-accent"] == "#84A98C"
      assert vars["--theme-highlight"] == "#F4E4C1"
      assert vars["--theme-bg"] == "#FFFBEB"
      assert vars["--theme-font-heading"] =~ "Lora"
      assert vars["--theme-font-body"] =~ "Inter"
    end

    test "section gates include lifestyle/crafts-specific keys", %{defaults: defaults} do
      assert defaults.sections.makers == true
      assert defaults.sections.rooms == true
      assert defaults.sections.story == true
      assert defaults.sections.bundles == true
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Heritage.renderer(:home) == Emakola.Themes.Heritage.Home
      assert Heritage.renderer(:product_list) == Emakola.Themes.Heritage.ProductList
      assert Heritage.renderer(:product_detail) == Emakola.Themes.Heritage.ProductDetail
      assert Heritage.renderer(:shared) == Emakola.Themes.Heritage.Shared
    end
  end
end
