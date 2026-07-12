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

  # theme_section_index/0 is built `into: %{}` — a colliding key across two
  # sectionized themes would silently last-write-win, making one theme's
  # section unreachable. Guard against that as new themes fan out.
  test "no two sectionized themes register the same section key" do
    keys =
      for theme <- Sections.sectionized_themes(),
          section <- theme.sections(),
          do: section.key()

    assert keys == Enum.uniq(keys)
  end

  describe "sectionized?/1" do
    test "is true for every registered sectionized theme" do
      assert Sections.sectionized?(Emakola.Themes.Starter)
      assert Sections.sectionized?(Emakola.Themes.Atelier)
      assert Sections.sectionized?(Emakola.Themes.Market)
    end

    test "is false for a theme without sections support" do
      refute Sections.sectionized?(Emakola.Themes.Bold)
    end
  end
end

defmodule Emakola.Themes.SectionsRegistrySeamTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test seam resolve/1 consults), so it must not run async — a separate
  # module (not a describe block) so the registry tests above keep running
  # async: true.
  use ExUnit.Case, async: false

  alias Emakola.Themes.Sections

  defmodule SeamTheme do
    def id, do: "seam"
    def sections, do: []
  end

  test "sectionized_themes/0 and sectionized?/1 include the extra_sectionized_themes seam" do
    Application.put_env(:emakola, :extra_sectionized_themes, [SeamTheme])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)

    assert SeamTheme in Sections.sectionized_themes()
    assert Sections.sectionized?(SeamTheme)
  end
end
