defmodule EmakolaWeb.GhanaMapTest do
  @moduledoc """
  The directory's map geometry.

  Ghana's region list already lives in two places — the supplier domain's
  `GhanaRegions` and the SEO surface's `Regions`. This module adds geometry,
  not a third vocabulary, so the first test here exists to make that true and
  keep it true: if any list gains or renames a region, this fails rather than
  the map quietly losing a shape.
  """
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.GhanaRegions
  alias EmakolaWeb.GhanaMap
  alias EmakolaWeb.SEO.Regions

  test "the map's regions are the same sixteen the rest of the app knows" do
    assert Enum.sort(GhanaMap.names()) == Enum.sort(GhanaRegions.all())
    assert Enum.sort(GhanaMap.names()) == Enum.sort(Regions.names())
    assert length(GhanaMap.names()) == 16
  end

  test "every region carries real boundary geometry, not a placeholder" do
    for region <- GhanaMap.regions() do
      assert String.starts_with?(region.d, "M"), "#{region.name} path is malformed"
      assert String.ends_with?(String.trim(region.d), "Z"), "#{region.name} path is not closed"

      # The blob this replaced was twenty points for the whole country.
      points = region.d |> String.split(" L") |> length()
      assert points > 20, "#{region.name} has only #{points} points — too crude to be real"
    end
  end

  test "every label anchor sits inside the viewBox" do
    [_, _, w, h] = GhanaMap.view_box() |> String.split(" ") |> Enum.map(&String.to_integer/1)

    for region <- GhanaMap.regions() do
      assert region.label_x > 0 and region.label_x < w, "#{region.name} label off-canvas"
      assert region.label_y > 0 and region.label_y < h, "#{region.name} label off-canvas"
    end
  end

  test "Greater Accra sits on the coast and Upper East in the north" do
    by_name = Map.new(GhanaMap.regions(), &{&1.name, &1})

    # y grows downward, so the coastal region's anchor must be far below the
    # northern one's. A mirrored or unprojected map fails here.
    assert by_name["Greater Accra"].label_y > by_name["Upper East"].label_y + 800
    assert by_name["Greater Accra"].label_x > by_name["Western"].label_x
  end
end
