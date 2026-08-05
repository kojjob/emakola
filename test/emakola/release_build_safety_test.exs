defmodule Emakola.ReleaseBuildSafetyTest do
  @moduledoc """
  Catches a bug class that CI is structurally incapable of catching.

  The Dockerfile pins `ELIXIR_VERSION=1.18.3`; CI and local development run
  1.20.x. On 1.18.3 a `%__MODULE__{}` pattern inside an Ash resource expands
  **before** Spark has defined the struct, so the module compiles everywhere
  except the release image:

      error: Emakola.Catalog.Product.__struct__/1 is undefined,
      cannot expand struct Emakola.Catalog.Product

  No test run, no `mix compile --warnings-as-errors`, and no CI job can
  reproduce that — they all compile on a version where it works. The only thing
  that catches it is `fly deploy` failing, ~15 minutes in, after a Docker build.

  It has now cost three failed deploys: `pay_link.ex` and `susu_plan.ex` both
  carry comments about it, and `product.ex` hit it again in #386. A convention
  that relies on remembering has failed three times, so this asserts it instead.

  The real fix is aligning the Dockerfile's Elixir with CI's. Until that lands,
  this test is the guard — and it costs milliseconds.
  """
  use ExUnit.Case, async: true

  @resource_globs [
    "lib/emakola/*/resources/*.ex",
    "lib/emakola/*/resources/**/*.ex"
  ]

  # Matches `%__MODULE__{` only in code, not in a comment or a docstring —
  # those files legitimately *discuss* the pattern in warnings to future
  # readers, and flagging that would train people to ignore this test.
  defp offending_lines(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _no} ->
      trimmed = String.trim_leading(line)
      String.starts_with?(trimmed, "#") or String.starts_with?(trimmed, "`")
    end)
    |> Enum.filter(fn {line, _no} -> String.contains?(line, "%__MODULE__{") end)
  end

  defp resource_files do
    @resource_globs
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
  end

  test "no Ash resource pattern-matches on %__MODULE__{}" do
    files = resource_files()

    # If the glob ever stops finding resources, this test would pass
    # vacuously and guard nothing.
    assert length(files) > 10,
           "expected to scan many resource files, found #{length(files)} — has the layout moved?"

    offenders =
      files
      |> Enum.flat_map(fn path ->
        path
        |> offending_lines()
        |> Enum.map(fn {line, no} -> "#{path}:#{no}: #{String.trim(line)}" end)
      end)

    assert offenders == [],
           """
           %__MODULE__{} in an Ash resource compiles locally and in CI, but NOT in the
           release image (Dockerfile pins Elixir 1.18.3, where the struct expands before
           Spark defines it). This fails `fly deploy` ~15 minutes in, after a Docker build.

           Match the map shape instead — behaviour is identical:

               def thing?(%__MODULE__{field: f}), do: ...   # breaks the release build
               def thing?(%{field: f}), do: ...             # works everywhere

           Offending lines:
           #{Enum.join(offenders, "\n")}
           """
  end

  test "the scan actually detects the pattern it is guarding against" do
    # A guard that cannot fail is not a guard. This proves the detection works
    # without needing to break a real resource to find out.
    tmp =
      Path.join(System.tmp_dir!(), "release_guard_probe_#{System.unique_integer([:positive])}.ex")

    File.write!(tmp, """
    defmodule Probe do
      # %__MODULE__{} here is a comment and must NOT be flagged
      def a(%__MODULE__{x: x}), do: x
    end
    """)

    offenders = offending_lines(tmp)
    File.rm!(tmp)

    assert length(offenders) == 1, "the scan should flag the code line and skip the comment"
    assert {line, 3} = hd(offenders)
    assert String.contains?(line, "def a(")
  end
end
