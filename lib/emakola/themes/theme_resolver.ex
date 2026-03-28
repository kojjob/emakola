defmodule Emakola.Themes.ThemeResolver do
  @moduledoc """
  Resolves and merges theme configuration for a store.

  Takes a store's theme_config map (string keys from JSON) and:
  1. Identifies the theme module from the "theme" key
  2. Loads the theme's defaults
  3. Deep-merges merchant overrides on top of defaults
  4. Returns a config map with atom keys
  """

  @theme_modules %{
    "atelier" => Emakola.Themes.Atelier,
    "bold" => Emakola.Themes.Bold,
    "fresh" => Emakola.Themes.Fresh,
    "market" => Emakola.Themes.Market,
    "starter" => Emakola.Themes.Starter,
    "vibrant" => Emakola.Themes.Vibrant
  }

  @default_theme "market"

  @doc """
  Resolves theme configuration by merging merchant overrides with theme defaults.

  Accepts a theme_config map with string keys (as stored in the database).
  Returns a map with atom keys containing the fully resolved configuration.
  """
  @spec resolve(map() | nil) :: map()
  def resolve(nil), do: resolve(%{})

  def resolve(config) when is_map(config) do
    theme_id = Map.get(config, "theme", @default_theme)
    theme_mod = theme_module(theme_id)
    defaults = theme_mod.defaults()

    %{
      theme_id: theme_id,
      theme_name: theme_mod.name(),
      colors: deep_merge_atomize(defaults.colors, Map.get(config, "colors", %{})),
      fonts: deep_merge_atomize(defaults.fonts, Map.get(config, "fonts", %{})),
      hero: deep_merge_atomize(defaults.hero, Map.get(config, "hero", %{})),
      nav: deep_merge_atomize(defaults.nav, Map.get(config, "nav", %{})),
      sections: deep_merge_atomize(defaults.sections, Map.get(config, "sections", %{})),
      trust: deep_merge_atomize(defaults.trust, Map.get(config, "trust", %{})),
      newsletter: deep_merge_atomize(defaults.newsletter, Map.get(config, "newsletter", %{})),
      footer: deep_merge_atomize(defaults.footer, Map.get(config, "footer", %{}))
    }
  end

  @doc """
  Returns the theme module for a given theme ID string.

  Falls back to Market for unknown theme IDs.
  """
  @spec theme_module(String.t()) :: module()
  def theme_module(theme_id) when is_binary(theme_id) do
    Map.get(@theme_modules, theme_id, Emakola.Themes.Market)
  end

  # Deep-merges an overrides map (string keys) into a defaults map (atom keys).
  # Converts string keys to atoms in the process.
  defp deep_merge_atomize(defaults, overrides) when is_map(defaults) and is_map(overrides) do
    Enum.reduce(overrides, defaults, fn {key, value}, acc ->
      case safe_to_atom(key) do
        {:ok, atom_key} ->
          if Map.has_key?(acc, atom_key) do
            Map.put(acc, atom_key, value)
          else
            acc
          end

        :error ->
          acc
      end
    end)
  end

  defp deep_merge_atomize(defaults, _), do: defaults

  defp safe_to_atom(key) when is_atom(key), do: {:ok, key}

  defp safe_to_atom(key) when is_binary(key) do
    {:ok, String.to_existing_atom(key)}
  rescue
    ArgumentError -> :error
  end
end
