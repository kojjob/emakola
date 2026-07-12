defmodule Emakola.Themes.SectionContractTest do
  @moduledoc """
  The contract every sectionized theme must satisfy, checked for all of them at
  once. These are cheap assertions guarding expensive failures.

  The `default:` rule is the important one: the section editor's `coerce_value/2`
  pattern-matches on a schema entry's `default:` to decide what to fall back to
  when a merchant submits something unexpected. A schema entry without one
  crashes the editor — and because the merchant's draft lives only in socket
  assigns until they hit Publish, a crash silently destroys unpublished work.
  So a missing `default:` is not a lint nit; it is data loss.

  With nineteen themes now registered, nobody is going to remember this by hand.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Sections

  @themes Sections.sectionized_themes()

  test "there are sectionized themes to check (guards against a vacuous suite)" do
    refute @themes == [],
           "no sectionized themes registered — every assertion below would pass vacuously"
  end

  for theme <- @themes do
    describe "#{inspect(theme)} sections" do
      test "expose the Section behaviour and a non-empty ordered list" do
        sections = unquote(theme).sections()

        refute sections == [], "#{inspect(unquote(theme))} registers no sections"

        for section <- sections do
          assert is_binary(section.key()), "#{inspect(section)}.key/0 must return a string"
          assert is_binary(section.label()), "#{inspect(section)}.label/0 must return a string"
          assert is_list(section.settings_schema())
        end
      end

      test "every settings_schema entry declares a default" do
        for section <- unquote(theme).sections(),
            field <- section.settings_schema() do
          assert Map.has_key?(field, :default),
                 "#{inspect(section)} field #{inspect(field[:key])} has no `default:`. " <>
                   "The section editor's coerce_value/2 falls back to it; without one, a " <>
                   "crafted or unexpected value crashes the editor and destroys the " <>
                   "merchant's unpublished draft."
        end
      end

      test "section keys are unique and namespaced to the theme" do
        keys = Enum.map(unquote(theme).sections(), & &1.key())

        assert keys == Enum.uniq(keys),
               "#{inspect(unquote(theme))} has duplicate section keys: #{inspect(keys -- Enum.uniq(keys))}"

        prefix = unquote(theme).id() <> "/"

        for key <- keys do
          assert String.starts_with?(key, prefix),
                 "section key #{inspect(key)} is not namespaced to #{inspect(prefix)} — " <>
                   "keys collide across themes in the shared registry otherwise"
        end
      end

      test "every section resolves through the registry" do
        for section <- unquote(theme).sections() do
          assert {:ok, {module, _meta}} = Sections.resolve(section.key()),
                 "#{section.key()} does not resolve — the editor cannot render it"

          assert module == section
        end
      end
    end
  end
end
