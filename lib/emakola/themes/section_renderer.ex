defmodule Emakola.Themes.SectionRenderer do
  @moduledoc """
  Renders a store's effective home-section layout: saved layout for the
  active theme when present, else the theme's `sections/0` defaults —
  making untouched stores byte-identical to the pre-section themes.

  Each enabled entry renders inside the universal style wrapper
  (validated background/text color + a padding scale) — v1 "full
  theming" with zero per-section CSS work.
  """

  use Phoenix.Component

  require Logger

  alias Emakola.Themes.{HomeSections, Sections}

  @padding_classes %{
    "none" => "py-0",
    "sm" => "py-4 sm:py-6",
    "md" => "py-8 sm:py-12",
    "lg" => "py-14 sm:py-20"
  }

  def home(assigns) do
    entries =
      HomeSections.effective_layout(assigns.store, assigns.theme_module)
      |> Enum.filter(& &1["enabled"])
      |> Enum.flat_map(fn entry ->
        case Sections.resolve(entry["type"]) do
          {:ok, {module, meta}} ->
            [{entry, module, meta}]

          :error ->
            Logger.warning(
              "[sections] unknown section type #{inspect(entry["type"])} skipped " <>
                "(store=#{assigns.store.id})"
            )

            []
        end
      end)

    assigns = assign(assigns, :resolved_entries, entries)

    ~H"""
    <div
      :for={{entry, module, meta} <- @resolved_entries}
      class={padding_class(entry["style"])}
      style={wrapper_style(entry["style"])}
      data-section-id={entry["id"]}
      data-section-padding={entry["style"]["padding"]}
    >
      {render_section(module, meta, entry, assigns)}
    </div>
    """
  end

  defp render_section(module, meta, entry, assigns) do
    settings = Map.merge(schema_defaults(module), entry["settings"] || %{})

    assigns
    |> Map.drop([:resolved_entries])
    |> Map.put(:settings, settings)
    |> Map.put(:section_meta, meta)
    |> module.render()
  end

  defp schema_defaults(module) do
    for setting <- module.settings_schema(), into: %{} do
      {setting.key, setting.default}
    end
  end

  defp padding_class(%{"padding" => padding}), do: Map.get(@padding_classes, padding)
  defp padding_class(_style), do: nil

  defp wrapper_style(style) do
    [
      style["bg"] && "background-color: #{style["bg"]}",
      style["text"] && "color: #{style["text"]}"
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, "; ")
    end
  end
end
