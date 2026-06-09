defmodule Emakola.Themes.SpotlightTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "registration & contract" do
    test "resolver resolves spotlight with the light palette" do
      config = ThemeResolver.resolve(%{"theme" => "spotlight"})
      assert config.theme_id == "spotlight"
      assert config.theme_name == "Spotlight"
      assert config.colors.background == "#FBF9F5"
      assert config.colors.accent == "#7C3AED"
    end

    test "implements required ThemeBehaviour callbacks" do
      Code.ensure_loaded!(Emakola.Themes.Spotlight)
      assert Emakola.Themes.Spotlight.name() == "Spotlight"

      for {fun, arity} <- [
            render_home: 1,
            render_product_list: 1,
            render_product_detail: 1,
            css_variables: 0,
            name: 0
          ] do
        assert function_exported?(Emakola.Themes.Spotlight, fun, arity), "missing #{fun}/#{arity}"
      end
    end

    test "css_variables exposes theme custom properties" do
      vars = Emakola.Themes.Spotlight.css_variables()
      assert vars["--theme-bg"] == "#FBF9F5"
      assert vars["--theme-accent"] == "#7C3AED"
    end

    test "ingredients/0 returns a non-empty list of name+description maps" do
      items = Emakola.Themes.Spotlight.ingredients()
      assert is_list(items) and length(items) >= 3
      assert Enum.all?(items, &(is_binary(&1.name) and is_binary(&1.description)))
    end
  end
end
