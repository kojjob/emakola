defmodule Emakola.Themes.HomeSections do
  @moduledoc """
  Per-theme home-section layouts inside `store.theme_config["home_sections"]`
  (`%{"v" => 1, <theme_id> => [entry]}`). No migration; unknown keys are
  sanitized away on write and skipped on read.

  Writes key layouts by the canonical theme id (the `theme_config["theme"]`
  value, e.g. `"starter"`); anything that isn't a known theme id — including
  the reserved `"v"` envelope key — is rejected with `{:error, :unknown_theme}`.
  """

  require Ash.Query

  alias Emakola.Themes.ThemeResolver

  @paddings ~w(none sm md lg)
  @config_key "home_sections"
  @url_setting_types [:image_url, :link]

  def default_layout(theme_module) do
    for section <- theme_module.sections() do
      %{
        "id" => section.key(),
        "type" => section.key(),
        "enabled" => true,
        "settings" => %{},
        "style" => %{}
      }
    end
  end

  def saved_layout(store, theme_name) do
    case get_in(store.theme_config || %{}, [@config_key, theme_name]) do
      entries when is_list(entries) -> entries
      _missing -> nil
    end
  end

  def effective_layout(store, theme_module) do
    saved_layout(store, theme_module.id()) || default_layout(theme_module)
  end

  def put_layout(actor, store, theme_name, entries) when is_list(entries) do
    with :ok <- validate_theme_name(theme_name),
         :ok <- ensure_store_access(actor, store.id) do
      sanitized = entries |> Enum.map(&sanitize_entry/1) |> Enum.reject(&is_nil/1)

      existing = store.theme_config || %{}
      section_map = Map.get(existing, @config_key, %{"v" => 1})

      config =
        Map.put(existing, @config_key, Map.put(section_map, theme_name, sanitized))

      update_theme_config(store, config)
    end
  end

  def clear_layout(actor, store, theme_name) do
    with :ok <- validate_theme_name(theme_name),
         :ok <- ensure_store_access(actor, store.id) do
      existing = store.theme_config || %{}
      section_map = existing |> Map.get(@config_key, %{}) |> Map.delete(theme_name)
      update_theme_config(store, Map.put(existing, @config_key, section_map))
    end
  end

  # ── sanitization ────────────────────────────────────────────────

  @doc false
  # Public so the schema-scoped URL rule is testable with an explicit section
  # module — the registry resolves only "block/..." keys until the theme
  # fan-out registers sectionized themes.
  def sanitize_entry(%{} = entry, section_module) do
    type = entry["type"] || entry[:type]

    if is_binary(type) do
      id = entry["id"] || entry[:id]

      %{
        "id" => if(is_binary(id), do: id, else: type),
        "type" => type,
        "enabled" => (entry["enabled"] || entry[:enabled]) == true,
        "settings" =>
          sanitize_settings(
            entry["settings"] || entry[:settings] || %{},
            url_keys(section_module)
          ),
        "style" => sanitize_style(entry["style"] || entry[:style] || %{})
      }
    end
  end

  def sanitize_entry(_other, _section_module), do: nil

  defp sanitize_entry(%{} = entry) do
    type = entry["type"] || entry[:type]

    case is_binary(type) && Emakola.Themes.Sections.resolve(type) do
      {:ok, {module, _meta}} -> sanitize_entry(entry, module)
      _invalid -> nil
    end
  end

  defp sanitize_entry(_other), do: nil

  defp url_keys(section_module) do
    for %{key: key, type: type} <- section_module.settings_schema(),
        type in @url_setting_types,
        do: key
  end

  defp sanitize_settings(%{} = settings, url_keys) do
    for {key, value} <- settings,
        is_binary(key),
        sane_setting_value?(value, key in url_keys),
        into: %{} do
      {key, value}
    end
  end

  defp sanitize_settings(_other, _url_keys), do: %{}

  # Scalars only. URL-typed keys (schema type :image_url/:link) must be
  # scheme-less (relative) or http(s) — blocks javascript:/data: URIs in
  # href/src positions. Other string values pass through as-is: they render
  # HEEx-escaped, so a colon in a heading ("Sale: Ends Friday") is inert.
  # Block-bridge sections declare no schema, mirroring the page builder's
  # verbatim content bar.
  defp sane_setting_value?(value, _url_key?) when is_boolean(value) or is_integer(value), do: true

  defp sane_setting_value?(value, false) when is_binary(value), do: true

  defp sane_setting_value?(value, true) when is_binary(value) do
    scheme = value |> String.trim() |> String.downcase()

    not String.contains?(scheme, ":") or
      String.starts_with?(scheme, "http://") or
      String.starts_with?(scheme, "https://")
  end

  defp sane_setting_value?(_other, _url_key?), do: false

  defp sanitize_style(%{} = style) do
    bg = EmakolaWeb.Helpers.CssColor.safe_css_color(style["bg"] || "", nil)
    text = EmakolaWeb.Helpers.CssColor.safe_css_color(style["text"] || "", nil)
    padding = if style["padding"] in @paddings, do: style["padding"]

    [{"bg", bg}, {"text", text}, {"padding", padding}]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp sanitize_style(_other), do: %{}

  # ThemeResolver exposes no known-ids list, but its public theme_module/1
  # round-trips exactly: unknown ids fall back to Market, whose id/0 won't
  # echo the input. Rejects unknown themes, non-binary names, and the
  # reserved "v" envelope key without modifying ThemeResolver. The seam
  # clause lets tests exercise a fake theme not registered with
  # ThemeResolver — see the matching seam in Sections.resolve/1.
  defp validate_theme_name(theme_name) when is_binary(theme_name) do
    if ThemeResolver.theme_module(theme_name).id() == theme_name or seam_theme?(theme_name) do
      :ok
    else
      {:error, :unknown_theme}
    end
  end

  defp validate_theme_name(_theme_name), do: {:error, :unknown_theme}

  # Test-only seam: mirrors Sections.resolve/1's extra_sectionized_themes
  # env so put_layout/clear_layout accept a fake theme's name in tests
  # without registering it as a real theme. Not read outside test config.
  defp seam_theme?(theme_name) do
    Application.get_env(:emakola, :extra_sectionized_themes, [])
    |> Enum.any?(&(&1.id() == theme_name))
  end

  defp update_theme_config(store, config) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: config})
    |> Ash.update(authorize?: false)
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
