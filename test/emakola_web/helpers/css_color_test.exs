defmodule EmakolaWeb.Helpers.CssColorTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Helpers.CssColor

  @default "#2563EB"

  describe "safe_css_color/2" do
    test "passes through a valid 6-digit hex color" do
      assert CssColor.safe_css_color("#B45309", @default) == "#B45309"
    end

    test "passes through a valid 3-digit hex color" do
      assert CssColor.safe_css_color("#fff", @default) == "#fff"
    end

    test "passes through a valid 8-digit hex color with alpha" do
      assert CssColor.safe_css_color("#FFFFFF80", @default) == "#FFFFFF80"
    end

    test "returns the default for nil" do
      assert CssColor.safe_css_color(nil, @default) == @default
    end

    test "returns the default for an empty string" do
      assert CssColor.safe_css_color("", @default) == @default
    end

    test "returns the default for a named color" do
      assert CssColor.safe_css_color("red", @default) == @default
    end

    test "returns the default for a CSS injection payload" do
      assert CssColor.safe_css_color("red;background:url(//evil)", @default) == @default
    end

    test "returns the default for a style-breaking payload" do
      assert CssColor.safe_css_color("</style><script>", @default) == @default
    end

    test "returns the default for a url() value" do
      assert CssColor.safe_css_color("url(x)", @default) == @default
    end

    test "returns the default for invalid hex digits" do
      assert CssColor.safe_css_color("#GGG123", @default) == @default
    end

    test "returns the default for a non-binary value" do
      assert CssColor.safe_css_color(123, @default) == @default
    end
  end
end
