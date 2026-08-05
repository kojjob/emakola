defmodule EmakolaWeb.AdminFormSourceTest do
  use ExUnit.Case, async: true

  @admin_live_root "lib/emakola_web/live/admin"
  @admin_components "lib/emakola_web/components/admin_components.ex"
  @inventory_components "lib/emakola_web/components/inventory_components.ex"
  @core_components "lib/emakola_web/components/core_components.ex"

  test "admin LiveViews and their shared components do not use raw form tags" do
    offenders =
      [
        Path.join(@admin_live_root, "**/*.{ex,heex}"),
        @admin_components,
        @inventory_components,
        @core_components
      ]
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.flat_map(fn file ->
        file
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_number} ->
          if String.contains?(line, "<form") and
               not core_components_documentation_example?(file, line) do
            ["#{file}:#{line_number}"]
          else
            []
          end
        end)
      end)

    assert offenders == [], "raw <form tags found in: #{Enum.join(offenders, ", ")}"
  end

  defp core_components_documentation_example?(@core_components, line),
    do: String.trim(line) == "<form>...</form>"

  defp core_components_documentation_example?(_file, _line), do: false
end
