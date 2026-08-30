defmodule EmakolaWeb.StoresComponentsTest do
  @moduledoc """
  Pins the contract for the Ghana `<.map_view>` modal on `/stores`.

  These assert on the markup the parent LiveView hangs events off
  (`phx-click="select_region"`, `phx-value-region={name}`,
  `phx-click="close_map"`), and on the two things that were broken: the
  region value must be the canonical name `Store.region` holds, and the
  counts must arrive already tallied rather than be derived from whatever
  slice of stores the page had loaded.
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  alias EmakolaWeb.GhanaMap
  alias EmakolaWeb.StoresComponents

  describe "map_view/1 — closed state" do
    test "renders nothing visible when open is false" do
      assigns = %{counts: %{}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={false} />
        """)

      refute html =~ "fixed inset-0"
      refute html =~ "Stores across Ghana"
      refute html =~ "phx-click=\"close_map\""
    end

    test "defaults to closed when :open is omitted" do
      assigns = %{counts: %{}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} />
        """)

      refute html =~ "Stores across Ghana"
    end
  end

  describe "map_view/1 — open state" do
    setup do
      assigns = %{counts: %{}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={true} />
        """)

      %{html: html}
    end

    test "renders the modal shell and the close button", %{html: html} do
      assert html =~ "fixed inset-0"
      assert html =~ "z-50"
      assert html =~ "phx-click=\"close_map\""
      assert html =~ "phx-click-away=\"close_map\""
      assert html =~ "Browse by region"
      assert html =~ "Stores across Ghana"
      assert html =~ ~s(aria-label="Close map")
      assert html =~ "Pick a region to filter the directory."
    end

    test "draws real geometry, not a hand-drawn outline", %{html: html} do
      assert html =~ ~s(viewBox="#{GhanaMap.view_box()}")

      # One path per region, each with real boundary data rather than the
      # twenty-point blob this replaced.
      paths = html |> String.split("<path") |> length() |> Kernel.-(1)
      assert paths == 16, "expected 16 region paths, got #{paths}"

      for region <- GhanaMap.regions() do
        assert String.length(region.d) > 500,
               "#{region.name} path looks too crude to be a real boundary"
      end
    end

    test "credits the boundary data as its licence requires", %{html: html} do
      assert html =~ "OpenStreetMap"
      assert html =~ "CC BY-SA"
    end

    test "renders all sixteen regions with their canonical names", %{html: html} do
      for name <- GhanaMap.names() do
        assert html =~ name, "expected #{inspect(name)} to render"
      end
    end

    test "every region emits select_region with the canonical name, never a slug", %{html: html} do
      for name <- GhanaMap.names() do
        assert html =~ ~s(phx-value-region="#{name}"),
               "expected phx-value-region for #{name}"
      end

      # The value the directory filter matches on is the name, not a slug —
      # sending "greater_accra" against a column holding "Greater Accra" is
      # what made every region click return nothing.
      refute html =~ ~s(phx-value-region="greater_accra")

      handlers =
        html |> String.split(~s(phx-click="select_region")) |> length() |> Kernel.-(1)

      assert handlers == 32,
             "expected 32 select_region handlers (16 shapes + 16 rows), got #{handlers}"
    end
  end

  describe "map_view/1 — counts" do
    test "shows the counts it is given, keyed by canonical name" do
      assigns = %{counts: %{"Ashanti" => 2, "Greater Accra" => 1}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={true} />
        """)

      assert html =~ "2 stores"
      assert html =~ "1 store"
      assert html =~ "0 stores"
    end

    test "draws a number on the map only where there are stores" do
      assigns = %{counts: %{"Ashanti" => 7}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={true} />
        """)

      texts = html |> String.split("<text") |> length() |> Kernel.-(1)
      assert texts == 1, "expected one count drawn on the map, got #{texts}"
      assert html =~ ~r{<text[^>]*>\s*7\s*</text>}
    end

    test "shades a busier region differently from an empty one" do
      assigns = %{counts: %{"Ashanti" => 9}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={true} />
        """)

      # Empty regions take the neutral, stocked ones the amber ramp. Palette
      # classes, never raw hex — this file is on the design-consistency sweep.
      assert html =~ "fill-slate-100"
      assert html =~ "fill-amber-500"
      refute html =~ "fill=\"#"
    end

    test "the active region leaves the ramp for the chrome's emerald" do
      # Volta carries a count too, so the amber hover state a stocked but
      # unselected region gets is actually on the page to assert against.
      assigns = %{counts: %{"Ashanti" => 9, "Volta" => 2}}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view counts={@counts} open={true} active_region="Ashanti" />
        """)

      assert html =~ "fill-emerald-600"
      assert html =~ "ring-2 ring-emerald-600"
      assert html =~ "hover:border-amber-400"
    end
  end

  describe "region_rows/1" do
    test "returns Ghana's sixteen regions in display order" do
      names = StoresComponents.region_rows(%{}) |> Enum.map(&elem(&1, 0))

      assert names == GhanaMap.names()
      assert length(names) == 16
    end

    test "a region absent from the counts is zero, not missing" do
      assert Enum.all?(StoresComponents.region_rows(%{}), fn {_name, count} -> count == 0 end)
    end

    test "reads counts under the canonical name" do
      rows = StoresComponents.region_rows(%{"Ashanti" => 3, "Volta" => 1})

      assert {"Ashanti", 3} in rows
      assert {"Volta", 1} in rows
      assert {"Central", 0} in rows
    end

    test "a count under an unknown key is ignored rather than crashing" do
      rows = StoresComponents.region_rows(%{"Atlantis" => 4, "Ashanti" => 1})

      assert {"Ashanti", 1} in rows
      assert rows |> Enum.map(&elem(&1, 1)) |> Enum.sum() == 1
    end
  end
end
