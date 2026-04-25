defmodule Emakola.Themes.AtlasTest do
  @moduledoc """
  Pins the Atlas theme contract.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Atlas

  describe "module metadata" do
    test "id and name are stable" do
      assert Atlas.id() == "atlas"
      assert Atlas.name() == "Atlas"
    end

    test "fonts URL loads Inter + JetBrains Mono" do
      [url] = Atlas.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Inter"
      assert url =~ "JetBrains+Mono"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Atlas.defaults()}
    end

    test "uses light bg, slate primary, royal blue accent",
         %{defaults: defaults} do
      assert defaults.colors.background == "#FAFAFA"
      assert defaults.colors.primary == "#0F172A"
      assert defaults.colors.accent == "#2563EB"
      assert defaults.colors.highlight == "#F1F5F9"
    end

    test "uses Inter for both heading and body", %{defaults: defaults} do
      assert defaults.fonts.heading == "Inter"
      assert defaults.fonts.body == "Inter"
    end

    test "section gates include catalog-specific keys", %{defaults: defaults} do
      assert defaults.sections.whats_new == true
      assert defaults.sections.bestsellers == true
      assert defaults.sections.feed == true
    end
  end

  describe "Shared.pill_for/1" do
    test "cycles through the pill palette by index" do
      a = Emakola.Themes.Atlas.Shared.pill_for(0)
      b = Emakola.Themes.Atlas.Shared.pill_for(1)
      c = Emakola.Themes.Atlas.Shared.pill_for(6)

      assert is_map(a)
      assert is_map(b)
      assert a != b
      # Index 6 wraps back to index 0 (palette has 6 colors)
      assert a == c
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Atlas.renderer(:home) == Emakola.Themes.Atlas.Home
      assert Atlas.renderer(:product_list) == Emakola.Themes.Atlas.ProductList
      assert Atlas.renderer(:product_detail) == Emakola.Themes.Atlas.ProductDetail
      assert Atlas.renderer(:shared) == Emakola.Themes.Atlas.Shared
    end
  end
end
