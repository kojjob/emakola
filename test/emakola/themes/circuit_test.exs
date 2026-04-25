defmodule Emakola.Themes.CircuitTest do
  @moduledoc """
  Pins the Circuit theme contract.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Circuit

  describe "module metadata" do
    test "id and name are stable" do
      assert Circuit.id() == "circuit"
      assert Circuit.name() == "Circuit"
    end

    test "fonts URL loads Inter + JetBrains Mono" do
      [url] = Circuit.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Inter"
      assert url =~ "JetBrains+Mono"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Circuit.defaults()}
    end

    test "uses dark blue-tinted bg, white primary, electric blue accent",
         %{defaults: defaults} do
      assert defaults.colors.background == "#0F0F12"
      assert defaults.colors.primary == "#FFFFFF"
      assert defaults.colors.accent == "#3B82F6"
      assert defaults.colors.highlight == "#1A1A1F"
    end

    test "uses Inter for both heading and body", %{defaults: defaults} do
      assert defaults.fonts.heading == "Inter"
      assert defaults.fonts.body == "Inter"
    end

    test "section gates include tech-specific keys", %{defaults: defaults} do
      assert defaults.sections.compare == true
      assert defaults.sections.specs == true
      assert defaults.sections.capsules == true
    end

    test "newsletter is framed as stock alerts", %{defaults: defaults} do
      assert defaults.newsletter.title =~ "Stock"
      assert defaults.newsletter.button_text =~ "Notify"
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Circuit.renderer(:home) == Emakola.Themes.Circuit.Home
      assert Circuit.renderer(:product_list) == Emakola.Themes.Circuit.ProductList
      assert Circuit.renderer(:product_detail) == Emakola.Themes.Circuit.ProductDetail
      assert Circuit.renderer(:shared) == Emakola.Themes.Circuit.Shared
    end
  end
end
