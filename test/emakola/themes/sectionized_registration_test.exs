defmodule Emakola.Themes.SectionizedRegistrationTest do
  # async: false — reads the global :extra_sectionized_themes seam that other
  # theme tests write. Registration is compile-time state, not per-test state.
  use ExUnit.Case, async: false

  alias Emakola.Themes.{Sections, ThemeResolver}

  # A theme that implements `sections/0` but is NOT in `@sectionized_themes`
  # renders a BLANK storefront — chrome only, no content.
  #
  # Nothing crashes. `SectionRenderer` asks `Sections.resolve/1` for each of
  # the theme's own section keys, the registry doesn't know the theme, every
  # key comes back :error, and the renderer skips them all with a log warning
  # nobody reads. The merchant's home page simply empties out.
  #
  # That is the trap this file exists to close: the registry entry is not
  # bookkeeping, it is what makes a retrofitted theme render at all.
  test "every theme that implements sections/0 is registered as sectionized" do
    unregistered =
      for id <- ThemeResolver.theme_ids(),
          module = ThemeResolver.theme_module(id),
          Code.ensure_loaded?(module),
          function_exported?(module, :sections, 0),
          not Sections.sectionized?(module),
          do: id

    assert unregistered == [],
           """
           These themes implement sections/0 but are missing from
           @sectionized_themes in lib/emakola/themes/sections.ex:

               #{Enum.join(unregistered, ", ")}

           Their storefront home pages render CHROME ONLY — every section is
           silently skipped, because the registry cannot resolve their keys.
           Register them.
           """
  end

  test "every registered sectionized theme actually implements sections/0" do
    liars =
      for module <- Sections.sectionized_themes(),
          Code.ensure_loaded?(module),
          not function_exported?(module, :sections, 0),
          do: inspect(module)

    assert liars == [],
           "Registered as sectionized but has no sections/0: #{Enum.join(liars, ", ")}"
  end
end
