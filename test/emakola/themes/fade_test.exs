defmodule Emakola.Themes.FadeTest do
  @moduledoc """
  Pins the Fade theme contract — id, name, palette, fonts, defaults,
  section gates, and renderer dispatch.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Fade

  describe "module metadata" do
    test "id and name are stable" do
      assert Fade.id() == "fade"
      assert Fade.name() == "Fade"
    end

    test "fonts URL loads Space Grotesk + Inter + JetBrains Mono" do
      [url] = Fade.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Space+Grotesk"
      assert url =~ "Inter"
      assert url =~ "JetBrains+Mono"
      assert url =~ "display=swap"
    end
  end

  describe "defaults/0" do
    setup do
      {:ok, defaults: Fade.defaults()}
    end

    test "exposes id and name", %{defaults: defaults} do
      assert defaults.id == :fade
      assert defaults.name == "Fade"
    end

    test "uses dark background, off-white primary, neon accent",
         %{defaults: defaults} do
      assert defaults.colors.background == "#0A0A0A"
      assert defaults.colors.primary == "#FAFAFA"
      assert defaults.colors.accent == "#00FF85"
      assert defaults.colors.highlight == "#1F1F1F"
    end

    test "uses Space Grotesk heading + Inter body fonts", %{defaults: defaults} do
      assert defaults.fonts.heading == "Space Grotesk"
      assert defaults.fonts.body == "Inter"
    end

    test "css_variables map mirrors color and font defaults", %{defaults: defaults} do
      vars = defaults.css_variables
      assert vars["--theme-primary"] == "#FAFAFA"
      assert vars["--theme-accent"] == "#00FF85"
      assert vars["--theme-bg"] == "#0A0A0A"
      assert vars["--theme-font-heading"] =~ "Space Grotesk"
    end

    test "section gates include drop-driven keys", %{defaults: defaults} do
      assert defaults.sections.drop_counter == true
      assert defaults.sections.lookbook == true
      assert defaults.sections.capsules == true
    end

    test "newsletter is framed as early access", %{defaults: defaults} do
      assert defaults.newsletter.title =~ "Early"
      assert defaults.newsletter.button_text =~ "access"
    end
  end

  describe "renderer/1" do
    test "dispatches to the right page-type module" do
      assert Fade.renderer(:home) == Emakola.Themes.Fade.Home
      assert Fade.renderer(:product_list) == Emakola.Themes.Fade.ProductList
      assert Fade.renderer(:product_detail) == Emakola.Themes.Fade.ProductDetail
      assert Fade.renderer(:shared) == Emakola.Themes.Fade.Shared
    end
  end
end
