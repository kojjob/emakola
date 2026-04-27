defmodule EmakolaWeb.StoresComponentsTest do
  @moduledoc """
  Pins the contract for `EmakolaWeb.StoresComponents` — currently the
  Ghana `<.map_view>` modal used on the public `/stores` directory.

  These tests intentionally assert on the markup the parent LiveView
  hangs events off of (`phx-click="select_region"`,
  `phx-value-region={slug}`, `phx-click="close_map"`) so that Track D's
  wiring stays honest.
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  alias EmakolaWeb.StoresComponents

  describe "map_view/1 — closed state" do
    test "renders nothing visible when open is false" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={false} />
        """)

      refute html =~ "fixed inset-0"
      refute html =~ "Stores across Ghana"
      refute html =~ "phx-click=\"close_map\""
    end

    test "defaults to closed when :open is omitted" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} />
        """)

      refute html =~ "Stores across Ghana"
    end
  end

  describe "map_view/1 — open state" do
    test "renders the modal shell, the SVG outline, and the close button" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={true} />
        """)

      # Backdrop / shell
      assert html =~ "fixed inset-0"
      assert html =~ "z-50"
      assert html =~ "phx-click=\"close_map\""
      assert html =~ "phx-click-away=\"close_map\""

      # Header
      assert html =~ "Browse by region"
      assert html =~ "Stores across Ghana"
      assert html =~ ~s(aria-label="Close map")

      # SVG outline (the polygon path is inlined)
      assert html =~ "viewBox=\"0 0 400 500\""
      assert html =~ "<path"
      assert html =~ "fill=\"#fef3c7\""
      assert html =~ "stroke=\"#7A1F1F\""

      # Footer hint
      assert html =~ "Pick a region to filter the directory."
    end

    test "renders all 8 region buttons with their canonical labels" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={true} />
        """)

      for label <- [
            "Greater Accra",
            "Ashanti",
            "Central",
            "Western",
            "Eastern",
            "Northern",
            "Volta",
            "Other"
          ] do
        assert html =~ label, "expected #{inspect(label)} button to render"
      end
    end

    test "every region pin and button emits select_region with its slug" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={true} />
        """)

      for slug <- [
            "greater_accra",
            "ashanti",
            "central",
            "western",
            "eastern",
            "northern",
            "volta",
            "other"
          ] do
        assert html =~ "phx-value-region=\"#{slug}\"",
               "expected phx-value-region for #{slug}"
      end

      # The SVG <g> wrappers and the right-hand <button>s combined
      # should produce two select_region click handlers per region.
      select_count =
        html
        |> String.split("phx-click=\"select_region\"")
        |> length()
        |> Kernel.-(1)

      assert select_count == 16,
             "expected 16 select_region click handlers (8 pins + 8 buttons), got #{select_count}"
    end

    test "renders store counts derived from @stores" do
      stores = [
        %{region: "ashanti"},
        %{region: "ashanti"},
        %{region: "greater_accra"}
      ]

      assigns = %{stores: stores}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={true} />
        """)

      assert html =~ "2 stores"
      assert html =~ "1 store"
      # Singular vs plural copy must agree with the count.
      assert html =~ "0 stores"
    end

    test "active region gets emerald ring; inactive remain amber" do
      assigns = %{stores: []}

      html =
        rendered_to_string(~H"""
        <StoresComponents.map_view stores={@stores} open={true} active_region="ashanti" />
        """)

      assert html =~ "ring-2 ring-emerald-600"
      assert html =~ "border-emerald-600"
      # Non-active hover state still refers to amber.
      assert html =~ "hover:border-amber-400"
    end
  end

  describe "regions_with_counts/1" do
    test "returns the 8 canonical regions in canonical order" do
      result = StoresComponents.regions_with_counts([])

      slugs = Enum.map(result, &elem(&1, 0))

      assert slugs == [
               "greater_accra",
               "ashanti",
               "central",
               "western",
               "eastern",
               "northern",
               "volta",
               "other"
             ]
    end

    test "every entry is a {slug, label, 0} triple when stores is empty" do
      assert Enum.all?(
               StoresComponents.regions_with_counts([]),
               fn {slug, label, count} ->
                 is_binary(slug) and is_binary(label) and count == 0
               end
             )
    end

    test "tallies stores per region by their :region field" do
      stores = [
        %{region: "ashanti"},
        %{region: "ashanti"},
        %{region: "ashanti"},
        %{region: "greater_accra"},
        %{region: "volta"}
      ]

      result = StoresComponents.regions_with_counts(stores)

      assert {"ashanti", "Ashanti", 3} in result
      assert {"greater_accra", "Greater Accra", 1} in result
      assert {"volta", "Volta", 1} in result
      assert {"central", "Central", 0} in result
    end

    test "ignores stores with nil or missing :region" do
      stores = [
        %{region: nil},
        %{region: "ashanti"},
        %{}
      ]

      result = StoresComponents.regions_with_counts(stores)

      assert {"ashanti", "Ashanti", 1} in result

      total =
        result
        |> Enum.map(&elem(&1, 2))
        |> Enum.sum()

      assert total == 1
    end

    test "ignores unknown region slugs (e.g. typos) without crashing" do
      stores = [
        %{region: "atlantis"},
        %{region: "ashanti"}
      ]

      result = StoresComponents.regions_with_counts(stores)

      assert {"ashanti", "Ashanti", 1} in result

      total =
        result
        |> Enum.map(&elem(&1, 2))
        |> Enum.sum()

      assert total == 1
    end
  end
end
