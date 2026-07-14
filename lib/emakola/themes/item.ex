defmodule Emakola.Themes.Item do
  @moduledoc """
  Reads one field from a theme-config list item, whatever key shape it arrives in.

  Theme defaults are Elixir literals, so their items are atom-keyed
  (`%{title: "…"}`). A *merchant's* items are stored in `store.theme_config`,
  which is jsonb, so they come back string-keyed (`%{"title" => "…"}`) —
  `ThemeResolver.deep_merge_atomize/2` atomizes the keys it finds in the
  defaults, but a list of maps is carried through whole and its inner keys are
  never touched.

  Every section was written against the atom shape it saw in the theme file, so
  `item.title` raised a `KeyError` — a 500 — the moment a merchant supplied their
  own items. It went unnoticed while the items were platform-written and no
  merchant had ever set any.
  """

  @doc "The item's `key`, tolerating atom- or string-keyed maps. `default` when absent or blank."
  def field(item, key, default \\ nil) when is_map(item) and is_atom(key) do
    case Map.get(item, key, Map.get(item, Atom.to_string(key))) do
      nil -> default
      "" -> default
      value -> value
    end
  end

  @doc "True when the item carries `key` in either shape — used to reject blank rows."
  def has?(item, key) when is_map(item) and is_atom(key), do: field(item, key) != nil
end
