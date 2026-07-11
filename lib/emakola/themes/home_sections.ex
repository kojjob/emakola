defmodule Emakola.Themes.HomeSections do
  @moduledoc """
  Per-theme home-section layouts inside `store.theme_config["home_sections"]`
  (`%{"v" => 1, <theme_name> => [entry]}`). No migration; unknown keys are
  sanitized away on write and skipped on read.
  """

  require Ash.Query

  @paddings ~w(none sm md lg)
  @config_key "home_sections"

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
    with :ok <- ensure_store_access(actor, store.id) do
      sanitized = entries |> Enum.map(&sanitize_entry/1) |> Enum.reject(&is_nil/1)

      existing = store.theme_config || %{}
      section_map = Map.get(existing, @config_key, %{"v" => 1})

      config =
        Map.put(existing, @config_key, Map.put(section_map, theme_name, sanitized))

      update_theme_config(store, config)
    end
  end

  def clear_layout(actor, store, theme_name) do
    with :ok <- ensure_store_access(actor, store.id) do
      existing = store.theme_config || %{}
      section_map = existing |> Map.get(@config_key, %{}) |> Map.delete(theme_name)
      update_theme_config(store, Map.put(existing, @config_key, section_map))
    end
  end

  # ── sanitization ────────────────────────────────────────────────

  defp sanitize_entry(%{} = entry) do
    type = entry["type"] || entry[:type]

    case Emakola.Themes.Sections.resolve(type || "") do
      :error ->
        nil

      {:ok, _resolved} ->
        %{
          "id" => to_string(entry["id"] || entry[:id] || type),
          "type" => type,
          "enabled" => (entry["enabled"] || entry[:enabled]) == true,
          "settings" => sanitize_settings(entry["settings"] || entry[:settings] || %{}),
          "style" => sanitize_style(entry["style"] || entry[:style] || %{})
        }
    end
  end

  defp sanitize_entry(_other), do: nil

  defp sanitize_settings(%{} = settings) do
    for {key, value} <- settings,
        is_binary(key),
        sane_setting_value?(value),
        into: %{} do
      {key, value}
    end
  end

  defp sanitize_settings(_other), do: %{}

  # Strings that look like URLs must be http(s); everything textual is
  # rendered escaped by HEEx anyway — the URL rule blocks javascript: hrefs.
  defp sane_setting_value?(value) when is_boolean(value) or is_integer(value), do: true

  defp sane_setting_value?(value) when is_binary(value) do
    scheme = value |> String.trim() |> String.downcase()

    not String.contains?(scheme, ":") or
      String.starts_with?(scheme, "http://") or
      String.starts_with?(scheme, "https://")
  end

  defp sane_setting_value?(_other), do: false

  defp sanitize_style(%{} = style) do
    bg = EmakolaWeb.Helpers.CssColor.safe_css_color(style["bg"] || "", nil)
    text = EmakolaWeb.Helpers.CssColor.safe_css_color(style["text"] || "", nil)
    padding = if style["padding"] in @paddings, do: style["padding"]

    [{"bg", bg}, {"text", text}, {"padding", padding}]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp sanitize_style(_other), do: %{}

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
