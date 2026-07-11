defmodule Emakola.Themes.SectionRenderer do
  @moduledoc """
  Renders a store's effective home-section layout: saved layout for the
  active theme when present, else the theme's `sections/0` defaults —
  making untouched stores byte-identical to the pre-section themes.

  Entries carrying a style render inside the universal style wrapper
  (validated background/text color + a padding scale) — v1 "full
  theming" with zero per-section CSS work. Unstyled entries render
  bare, keeping default storefronts byte-identical to the pre-section
  themes.
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
      |> Enum.flat_map(&resolve_entry(&1, assigns.store.id))

    assigns = assign(assigns, :resolved_entries, entries)

    ~H"""
    <%= for {entry, module, meta} <- @resolved_entries do %>
      <%= if styled?(entry["style"]) do %>
        <div
          class={padding_class(entry["style"])}
          style={wrapper_style(entry["style"])}
          data-section-id={entry["id"]}
          data-section-padding={entry["style"]["padding"]}
        >
          {render_section(module, meta, entry, assigns)}
        </div>
      <% else %>
        {render_section(module, meta, entry, assigns)}
      <% end %>
    <% end %>
    """
  end

  # Spec amendment (88963c2): the wrapper is emitted only when the entry is
  # actually styled — unstyled entries render bare so default storefronts
  # keep today's exact DOM; the editor preview forces wrappers in preview
  # mode (next PR). Junk style keys that resolve to neither count as unstyled.
  defp styled?(style) do
    padding_class(style) != nil or wrapper_style(style) != nil
  end

  # theme_config is a bare map attribute: write paths other than
  # HomeSections.put_layout (raw Ash updates, migrations) can leave
  # non-map junk in the array. Skip it — a bad entry must never take
  # down the storefront home render.
  defp resolve_entry(%{} = entry, store_id) do
    if entry["enabled"], do: resolve_type(entry, store_id), else: []
  end

  defp resolve_entry(entry, store_id) do
    Logger.warning(
      "[sections] malformed layout entry #{inspect(entry, limit: 5, printable_limit: 120)} " <>
        "skipped (store=#{store_id})"
    )

    []
  end

  # A non-binary "type" is just as unresolvable as an unknown one —
  # Sections.resolve/1 only accepts binaries, so guard before calling.
  defp resolve_type(entry, store_id) do
    type = entry["type"]

    with true <- is_binary(type),
         {:ok, {module, meta}} <- Sections.resolve(type) do
      [{normalize_entry(entry, type), module, meta}]
    else
      _unresolvable ->
        Logger.warning(
          "[sections] unknown section type #{inspect(type)} skipped (store=#{store_id})"
        )

        []
    end
  end

  # Same corruption class as non-map entries, one level down: nested
  # fields written outside put_layout's sanitizer must not crash the
  # render — coerce junk to the shape the wrapper and render expect.
  defp normalize_entry(entry, type) do
    entry
    |> Map.update("id", type, &if(is_binary(&1), do: &1, else: type))
    |> Map.update("style", %{}, &if(is_map(&1), do: &1, else: %{}))
    |> Map.update("settings", %{}, &if(is_map(&1), do: &1, else: %{}))
  end

  defp render_section(module, meta, entry, assigns) do
    settings = Map.merge(schema_defaults(module), entry["settings"] || %{})

    assigns
    |> Map.drop([:resolved_entries])
    |> Map.put(:settings, settings)
    |> Map.put(:section_meta, meta)
    # Dynamic per-section renders opt out of change tracking so section
    # templates always re-render fully — same convention as BlockSection.
    |> Map.put(:__changed__, nil)
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
