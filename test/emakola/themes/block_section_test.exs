defmodule Emakola.Themes.BlockSectionTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Sections

  test "renders a bridged block with its default content" do
    {:ok, {module, meta}} = Sections.resolve("block/text_section")

    html =
      %{
        store: %{id: Ash.UUID.generate(), name: "Test Store"},
        products: [],
        categories: [],
        settings: %{},
        section_meta: meta,
        __changed__: nil
      }
      |> module.render()
      |> rendered_to_string()

    assert is_binary(html) and html != ""
  end

  test "merchant settings override the block's default content" do
    {:ok, {module, meta}} = Sections.resolve("block/text_section")

    html =
      %{
        store: %{id: Ash.UUID.generate(), name: "Test Store"},
        products: [],
        categories: [],
        settings: %{"title" => "Akwaaba Deals"},
        section_meta: meta,
        __changed__: nil
      }
      |> module.render()
      |> rendered_to_string()

    assert html =~ "Akwaaba Deals"
  end
end
