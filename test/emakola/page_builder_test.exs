defmodule Emakola.PageBuilderTest do
  @moduledoc """
  Pins the page-builder registry + dispatch contract:

    * Every registered block module implements the `Block` behaviour.
    * Lookup by `type/0` works for every registered block.
    * Unknown types return nil instead of raising — pages keep rendering
      even when a block module is removed.
    * `merged_content/2` fills missing fields from `default_content/0`
      and tolerates malformed content maps.
    * `render_block/2` dispatches the right module's `render/1`.
  """
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder

  describe "blocks/0" do
    test "returns all registered blocks" do
      assert length(PageBuilder.blocks()) == 10

      types = Enum.map(PageBuilder.blocks(), & &1.type())

      expected_types = ~w(
        hero_banner product_grid text_section image_banner
        split video audio faq testimonials spacer
      )

      for expected <- expected_types do
        assert expected in types,
               "expected #{expected} in registered block types, got #{inspect(types)}"
      end
    end

    test "every registered block implements all required callbacks" do
      for module <- PageBuilder.blocks() do
        assert is_binary(module.type()),
               "#{inspect(module)}.type/0 must return a string"

        assert is_binary(module.name()),
               "#{inspect(module)}.name/0 must return a string"

        assert is_binary(module.icon()),
               "#{inspect(module)}.icon/0 must return a string"

        assert is_map(module.default_content()),
               "#{inspect(module)}.default_content/0 must return a map"
      end
    end
  end

  describe "block_module_for/1" do
    test "returns the module for a registered type" do
      assert PageBuilder.block_module_for("hero_banner") ==
               Emakola.PageBuilder.Blocks.HeroBanner

      assert PageBuilder.block_module_for("spacer") ==
               Emakola.PageBuilder.Blocks.Spacer
    end

    test "returns nil for unknown types" do
      assert PageBuilder.block_module_for("nonexistent") == nil
      assert PageBuilder.block_module_for("") == nil
    end

    test "returns nil for nil input" do
      assert PageBuilder.block_module_for(nil) == nil
    end
  end

  describe "merged_content/2" do
    test "fills missing fields from default_content" do
      module = Emakola.PageBuilder.Blocks.HeroBanner
      block = %{"content" => %{"headline" => "Custom"}}

      merged = PageBuilder.merged_content(module, block)

      # Provided field overrides default
      assert merged.headline == "Custom"
      # Missing fields fall back to defaults
      assert merged.cta_label == "Shop now"
      assert merged.text_align == "left"
    end

    test "uses pure defaults when content is missing" do
      module = Emakola.PageBuilder.Blocks.HeroBanner
      assert PageBuilder.merged_content(module, %{}) == module.default_content()
    end

    test "tolerates content map with unknown string keys" do
      module = Emakola.PageBuilder.Blocks.Spacer
      block = %{"content" => %{"some_unknown_key" => "value", "height" => "lg"}}

      merged = PageBuilder.merged_content(module, block)

      # Known field overrides default
      assert merged.height == "lg"
    end
  end

  describe "render_block/2" do
    test "returns nil for unknown block type" do
      block = %{"id" => "abc", "type" => "nonexistent", "content" => %{}}

      assigns = %{
        store: %{name: "Test Store", slug: "test", currency: "GHS"},
        products: [],
        categories: []
      }

      assert PageBuilder.render_block(block, assigns) == nil
    end

    test "returns nil for malformed block (no type key)" do
      block = %{"content" => %{}}
      assigns = %{store: %{}, products: [], categories: []}

      assert PageBuilder.render_block(block, assigns) == nil
    end

    test "dispatches a registered block to its module's render/1" do
      block = %{"id" => "spacer-1", "type" => "spacer", "content" => %{"height" => "md"}}

      assigns = %{
        store: %{name: "Test Store", slug: "test", currency: "GHS"},
        products: [],
        categories: []
      }

      result = PageBuilder.render_block(block, assigns)
      refute is_nil(result)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()
      # Spacer renders an aria-hidden div with a height class
      assert html =~ ~s(aria-hidden="true")
      assert html =~ "h-10"
    end
  end
end
