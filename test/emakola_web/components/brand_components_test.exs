defmodule EmakolaWeb.BrandComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.BrandComponents

  # The roof is the one path present in every variant — assert on it rather than
  # on the whole mark, so re-drawing the counter never breaks these tests.
  @roof ~s(d="M32 7 L59 23 H5 Z")

  describe "logo_mark/1" do
    test "renders the stall mark, still, by default" do
      html = render_component(&BrandComponents.logo_mark/1, [])

      assert html =~ @roof
      refute html =~ "logo-reveal"
      refute html =~ "logo-loading"
    end

    test "each motion state adds only its own class" do
      for {motion, class} <- [
            {"reveal", "logo-reveal"},
            {"loading", "logo-loading"},
            {"awaiting", "logo-awaiting"},
            {"paid", "logo-paid"},
            {"splash", "logo-splash"}
          ] do
        html = render_component(&BrandComponents.logo_mark/1, motion: motion)

        assert html =~ class, "expected #{motion} to render #{class}"
        assert html =~ @roof
      end
    end

    test "the loading state draws separate scallops so they can ripple" do
      html = render_component(&BrandComponents.logo_mark/1, motion: "loading")

      # Six individually animatable scallops, not the one-piece valance path.
      assert html |> String.split(~s(class="logo-scallop")) |> length() == 7
    end

    test "the awaiting state adds a coin, drawn behind the roof so it falls in" do
      html = render_component(&BrandComponents.logo_mark/1, motion: "awaiting")

      assert html =~ "logo-coin"
      # Painted before the roof, so the roof hides it on the way down.
      assert :binary.match(html, "logo-coin") < :binary.match(html, "logo-roof")
    end

    test "the paid state adds the tick, and nothing else does" do
      assert render_component(&BrandComponents.logo_mark/1, motion: "paid") =~ "logo-tick"
      refute render_component(&BrandComponents.logo_mark/1, motion: "reveal") =~ "logo-tick"
    end

    test "states that do not need extra elements do not pay for them" do
      html = render_component(&BrandComponents.logo_mark/1, motion: "reveal")

      refute html =~ "logo-coin"
      refute html =~ "logo-scallop"
    end

    test "the reversed tone paints structure in snow for dark surfaces" do
      dark = render_component(&BrandComponents.logo_mark/1, tone: "reversed")
      light = render_component(&BrandComponents.logo_mark/1, [])

      assert dark =~ "#f1f5f9"
      refute dark =~ "#0c1526"
      assert light =~ "#0c1526"
    end

    test "gold stays gold in both tones — it is the one fixed colour" do
      for tone <- ~w(ink reversed) do
        assert render_component(&BrandComponents.logo_mark/1, tone: tone) =~ "#d4a843"
      end
    end

    test "size drives both dimensions" do
      html = render_component(&BrandComponents.logo_mark/1, size: 64)

      assert html =~ ~s(width="64")
      assert html =~ ~s(height="64")
    end

    test "it is decorative unless given a label" do
      assert render_component(&BrandComponents.logo_mark/1, []) =~ ~s(aria-hidden="true")

      labelled = render_component(&BrandComponents.logo_mark/1, label: "Makola.io")
      assert labelled =~ ~s(aria-label="Makola.io")
      assert labelled =~ ~s(role="img")
      refute labelled =~ "aria-hidden"
    end

    test "extra classes are kept alongside the motion class" do
      html = render_component(&BrandComponents.logo_mark/1, motion: "reveal", class: "shrink-0")

      assert html =~ "shrink-0"
      assert html =~ "logo-reveal"
    end
  end
end
