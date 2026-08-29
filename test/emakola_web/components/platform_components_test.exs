defmodule EmakolaWeb.PlatformComponentsTest do
  @moduledoc """
  The platform admin and the merchant admin must look like one product.

  They drifted for a long time: the platform kept its own stat tile with
  `rounded-2xl`, `gray-*` borders, a 36px chip and Material Symbols, while
  the merchant admin moved to the shared `stat_card` with design tokens.
  These tests pin the platform tile to the shared component so the two
  cannot separate again.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias EmakolaWeb.PlatformComponents

  describe "stat_tile/1" do
    test "renders the shared admin card, not its own markup" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile label="Total stores" value={12} color="blue" icon="storefront" />
        """)

      # Shared tokens, not the platform's old hand-rolled classes.
      assert html =~ "rounded-card"
      assert html =~ "border-border"
      refute html =~ "border-gray-200"
      refute html =~ "rounded-2xl"
    end

    test "translates a Material icon name to the admin's Heroicon set" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile label="Merchants" value={4} color="indigo" icon="people" />
        """)

      assert html =~ "hero-user-group"
      refute html =~ "material-symbols-outlined"
    end

    test "maps its colour vocabulary onto the shared tones" do
      assigns = %{}

      emerald =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile label="Orders" value={9} color="emerald" icon="shopping_bag" />
        """)

      rose =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile label="Failures" value={1} color="rose" icon="error" />
        """)

      # "emerald" maps to :success, NOT :primary — primary is the admin's
      # violet now, and routing the green vocabulary there would repaint every
      # green platform tile violet and leave the platform admin with no green.
      assert emerald =~ "from-emerald-50"
      assert emerald =~ "bg-emerald-500"
      assert rose =~ "from-danger-soft"
    end

    test "an unmapped icon name renders a plain glyph rather than nothing" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile label="Odd" value={0} color="slate" icon="not_a_real_icon" />
        """)

      # A name nobody mapped should look ordinary, never broken or blank.
      assert html =~ "hero-chart-bar"
    end

    test "keeps the id on the tile so platform tests can still target it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PlatformComponents.stat_tile id="stat-total-stores" label="Stores" value={3} color="blue" />
        """)

      assert html =~ ~s|id="stat-total-stores"|
    end
  end
end
