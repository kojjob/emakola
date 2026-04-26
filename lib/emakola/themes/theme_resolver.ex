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
    "beauty" => Emakola.Themes.Beauty,
    "bold" => Emakola.Themes.Bold,
    "electronics" => Emakola.Themes.Electronics,
    "fresh" => Emakola.Themes.Fresh,
    "home_living" => Emakola.Themes.HomeLiving,
    "market" => Emakola.Themes.Market,
    "pharmacy" => Emakola.Themes.Pharmacy,
    "starter" => Emakola.Themes.Starter,
    "vibrant" => Emakola.Themes.Vibrant
  }

  @default_theme "market"

  @doc """
  Resolves theme configuration by merging merchant overrides with theme defaults.

  Accepts a theme_config map with string keys (as stored in the database).
  Returns a map with atom keys containing the fully resolved configuration.

  When `store` is provided (the second arg), the store's social URL fields
  (`instagram_url`, `tiktok_url`, `facebook_url`, `youtube_url`, `x_url`) are
  overlaid onto `footer.social_links` so theme footers render the merchant's
  actual handles. Pass `nil` (the default) to resolve without store overlay
  — used by admin theme previews where store data isn't relevant.
  """
  @spec resolve(map() | nil, map() | nil) :: map()
  def resolve(config, store \\ nil)

  def resolve(nil, store), do: resolve(%{}, store)

  def resolve(config, store) when is_map(config) do
    theme_id = Map.get(config, "theme", @default_theme)
    theme_mod = theme_module(theme_id)
    defaults = theme_mod.defaults()

    footer =
      defaults.footer
      |> deep_merge_atomize(Map.get(config, "footer", %{}))
      |> overlay_store_social(store)

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
      footer: footer,
      design_tokens: Emakola.Themes.DesignTokens.resolve(Map.get(config, "design_tokens", %{}))
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

  # Overlay the store's social URL fields onto the footer.social_links map.
  # When `store` is nil the footer is returned unchanged. nil URL fields on
  # the store are treated as "no overlay" so theme defaults / merchant
  # theme_config overrides win for unset platforms.
  defp overlay_store_social(footer, nil), do: footer

  defp overlay_store_social(footer, store) when is_map(footer) and is_map(store) do
    overlay = %{
      instagram: Map.get(store, :instagram_url),
      tiktok: Map.get(store, :tiktok_url),
      facebook: Map.get(store, :facebook_url),
      youtube: Map.get(store, :youtube_url),
      twitter: Map.get(store, :x_url)
    }

    base = Map.get(footer, :social_links, %{})

    merged =
      Enum.reduce(overlay, base, fn
        {_key, nil}, acc -> acc
        {_key, ""}, acc -> acc
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    Map.put(footer, :social_links, merged)
  end

  defp overlay_store_social(footer, _), do: footer
end
