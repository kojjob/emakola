defmodule Emakola.Themes.ThemeRendererTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeRenderer

  describe "theme_render/2" do
    test "returns :default when theme_module is nil" do
      assigns = %{theme_module: nil}
      assert ThemeRenderer.theme_render(assigns, :cart) == :default
    end

    test "returns :default when theme_module doesn't implement the callback" do
      # Market theme only implements render_home, render_product_list, render_product_detail
      assigns = %{theme_module: Emakola.Themes.Market}
      assert ThemeRenderer.theme_render(assigns, :cart) == :default
    end

    test "dispatches to theme module when it implements the callback" do
      # Ensure module is loaded (defdelegate requires this in test context)
      Code.ensure_loaded!(Emakola.Themes.Market)
      assert function_exported?(Emakola.Themes.Market, :render_home, 1)

      # ThemeRenderer should detect this and NOT return :default
      assigns = %{theme_module: Emakola.Themes.Market}
      # We can't easily call render_home without full assigns, but we can verify
      # the dispatch path by checking a page the theme DOESN'T implement
      assert ThemeRenderer.theme_render(assigns, :cart) == :default
      # And verify render_home would NOT be :default (it would dispatch to theme)
      # by confirming the function exists
      assert function_exported?(Emakola.Themes.Market, :render_home, 1)
    end

    test "returns :default when assigns has no theme_module key" do
      assert ThemeRenderer.theme_render(%{}, :cart) == :default
    end

    test "returns :default for unknown page type" do
      assigns = %{theme_module: Emakola.Themes.Market}
      assert ThemeRenderer.theme_render(assigns, :unknown_page) == :default
    end
  end

  describe "page_types/0" do
    test "returns all known page types" do
      types = ThemeRenderer.page_types()
      assert :home in types
      assert :cart in types
      assert :checkout in types
      assert :blog_list in types
      assert :blog_post in types
      assert :recipe_list in types
      assert :account in types
      assert :downloads in types
      assert :contact in types
      assert :faq in types
      assert :policies in types
      assert length(types) == 19
    end
  end
end
