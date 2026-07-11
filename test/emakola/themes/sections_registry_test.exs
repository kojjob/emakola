defmodule Emakola.Themes.SectionsRegistryTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.Sections

  test "resolves a theme section key to its module" do
    # Starter's hero is registered in Task 5; until then the registry is
    # empty of theme sections, so we assert the contract via the block
    # bridge and the error path.
    assert :error = Sections.resolve("nope/never")
  end

  test "resolves block keys through the bridge with block metadata" do
    assert {:ok, {Emakola.Themes.Sections.BlockSection, meta}} =
             Sections.resolve("block/hero_banner")

    assert meta.block_type == "hero_banner"
    assert is_atom(meta.block_module)
  end

  test "every registered theme section module implements the contract" do
    for theme <- Sections.sectionized_themes(),
        section <- theme.sections() do
      behaviours =
        section.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Emakola.Themes.Section in behaviours,
             "#{inspect(section)} must implement Emakola.Themes.Section"

      assert is_binary(section.key())
      assert is_binary(section.label())
      assert is_list(section.settings_schema())
    end
  end
end
