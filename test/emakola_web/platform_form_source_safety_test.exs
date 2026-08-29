defmodule EmakolaWeb.PlatformFormSourceSafetyTest do
  use ExUnit.Case, async: true

  @platform_root Path.expand("../../lib/emakola_web/live/platform", __DIR__)

  test "platform LiveViews do not render raw form tags" do
    violations =
      ["**/*.ex", "**/*.heex"]
      |> Enum.flat_map(&Path.wildcard(Path.join(@platform_root, &1)))
      |> Enum.flat_map(&raw_form_lines/1)

    assert violations == [],
           "platform forms must use assigned to_form/2 values with <.form>: #{inspect(violations)}"
  end

  defp raw_form_lines(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      if Regex.match?(~r/<form(?:\s|>)/, line) do
        [{Path.relative_to_cwd(path), line_number}]
      else
        []
      end
    end)
  end
end
