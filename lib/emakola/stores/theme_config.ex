defmodule Emakola.Stores.ThemeConfig do
  @moduledoc """
  Validates theme_config JSON maps stored on Store resources.

  Theme config structure:
    %{
      "theme" => "atelier" | "market" | "starter" | "vibrant",
      "colors" => %{
        "primary" => "#hex",
        "secondary" => "#hex",
        "accent" => "#hex",
        "background" => "#hex",
        "text" => "#hex"
      },
      "hero" => %{
        "title" => string,
        "subtitle" => string,
        "image_url" => string
      },
      "sections" => %{
        "show_featured" => boolean,
        "show_categories" => boolean,
        "show_about" => boolean
      }
    }
  """

  @valid_themes ~w(atelier market starter vibrant)
  @hex_color_regex ~r/^#[0-9a-fA-F]{6}$/
  @valid_color_keys ~w(primary secondary accent background text)
  @valid_section_keys ~w(show_featured show_categories show_about)

  @doc """
  Validates a theme_config map. Returns :ok or {:error, reason}.

  Empty configs are valid.
  """
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(config) when config == %{}, do: :ok

  def validate(config) when is_map(config) do
    with :ok <- validate_theme(config),
         :ok <- validate_colors(config),
         :ok <- validate_sections(config),
         :ok <- validate_hero(config) do
      :ok
    end
  end

  def validate(_), do: {:error, "theme_config must be a map"}

  defp validate_theme(%{"theme" => theme}) when theme in @valid_themes, do: :ok

  defp validate_theme(%{"theme" => _}),
    do: {:error, "invalid theme name, must be one of: #{Enum.join(@valid_themes, ", ")}"}

  defp validate_theme(_), do: :ok

  defp validate_colors(%{"colors" => colors}) when is_map(colors) do
    invalid =
      Enum.find(colors, fn {key, value} ->
        key in @valid_color_keys and not Regex.match?(@hex_color_regex, to_string(value))
      end)

    case invalid do
      nil -> :ok
      {key, _value} -> {:error, "invalid hex color for #{key}"}
    end
  end

  defp validate_colors(_), do: :ok

  defp validate_sections(%{"sections" => sections}) when is_map(sections) do
    invalid =
      Enum.find(sections, fn {key, value} ->
        key in @valid_section_keys and not is_boolean(value)
      end)

    case invalid do
      nil -> :ok
      {key, _value} -> {:error, "section #{key} must be a boolean"}
    end
  end

  defp validate_sections(_), do: :ok

  defp validate_hero(%{"hero" => hero}) when is_map(hero), do: :ok
  defp validate_hero(_), do: :ok
end
