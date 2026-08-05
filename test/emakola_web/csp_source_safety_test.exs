defmodule EmakolaWeb.CSPSourceSafetyTest do
  use ExUnit.Case, async: true

  @templates Path.expand("../../lib/emakola_web/**/*.html.heex", __DIR__)

  test "HEEx templates do not use inline DOM event-handler attributes" do
    violations =
      @templates
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> then(&Regex.scan(~r/\son[a-z]+\s*=/i, &1))
        |> Enum.map(fn [match] -> {Path.relative_to_cwd(path), String.trim(match)} end)
      end)

    assert violations == [],
           "inline event handlers are blocked by CSP; use phx-click or bundled app.js: #{inspect(violations)}"
  end

  test "HEEx script tags are external assets or non-executable approved types" do
    violations =
      @templates
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> then(&Regex.scan(~r/<script\b([^>]*)>/i, &1, capture: :all_but_first))
        |> Enum.reject(fn [attributes] -> approved_script_attributes?(attributes) end)
        |> Enum.map(fn [attributes] -> {Path.relative_to_cwd(path), String.trim(attributes)} end)
      end)

    assert violations == [],
           "custom scripts must live in the app.js bundle: #{inspect(violations)}"
  end

  defp approved_script_attributes?(attributes) do
    String.contains?(attributes, "src=") or
      String.contains?(attributes, "application/ld+json") or
      String.contains?(attributes, "Phoenix.LiveView.ColocatedHook")
  end
end
