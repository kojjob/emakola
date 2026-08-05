defmodule Emakola.RuntimeEnvironmentDocumentationTest do
  use ExUnit.Case, async: true

  @project_root Path.expand("../..", __DIR__)
  @runtime_path Path.join(@project_root, "config/runtime.exs")
  @example_path Path.join(@project_root, ".env.example")

  test ".env.example documents every active runtime environment variable" do
    runtime_source =
      @runtime_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
      |> Enum.join("\n")

    runtime_variables =
      ~r/System\.(?:get_env|fetch_env!)\("([A-Z0-9_]+)"/
      |> Regex.scan(runtime_source, capture: :all_but_first)
      |> List.flatten()
      |> MapSet.new()

    documented_variables =
      ~r/^#\s*([A-Z][A-Z0-9_]*)=/m
      |> Regex.scan(File.read!(@example_path), capture: :all_but_first)
      |> List.flatten()
      |> MapSet.new()

    missing_variables =
      runtime_variables
      |> MapSet.difference(documented_variables)
      |> Enum.sort()

    assert missing_variables == [],
           "add runtime variables to .env.example: #{Enum.join(missing_variables, ", ")}"
  end

  test ".env.example cannot activate placeholder credentials when loaded" do
    active_assignments =
      ~r/^[A-Z][A-Z0-9_]*=.*/m
      |> Regex.scan(File.read!(@example_path))
      |> List.flatten()

    assert active_assignments == []
  end
end
