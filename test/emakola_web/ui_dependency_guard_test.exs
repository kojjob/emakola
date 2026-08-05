defmodule EmakolaWeb.UiDependencyGuardTest do
  @moduledoc """
  Guards the project-owned UI boundary against silent reintroduction of the
  removed component plugin and unconditional remote typography.

  Merchant-selected storefront fonts are intentionally outside this guard:
  they are an explicit storefront feature and are loaded only when a merchant
  chooses a theme or design-token font. Material Symbols is also a temporary,
  explicit exception in the root layout until its project-wide icon usages can
  be migrated without making icons disappear.
  """

  use ExUnit.Case, async: true

  @project_ui_globs [
    "assets/css/**/*.css",
    "assets/js/**/*.js",
    "lib/emakola_web/**/*.ex",
    "lib/emakola_web/**/*.heex",
    "lib/emakola/themes/**/*.ex"
  ]

  @distinctive_component_classes ~r/(?:^|[\s"'])(?:
    btn-(?:primary|secondary|accent|neutral|info|success|warning|error|outline|dash|soft|ghost|link|active|disabled|xs|sm|md|lg|xl|wide|block|square|circle)|
    badge-(?:primary|secondary|accent|neutral|info|success|warning|error|outline|dash|soft|ghost|xs|sm|md|lg|xl)|
    checkbox-(?:primary|secondary|accent|neutral|info|success|warning|error|xs|sm|md|lg|xl)|
    (?:select|textarea|input)-(?:primary|secondary|accent|neutral|info|success|warning|error|ghost|xs|sm|md|lg|xl)|
    table-zebra|list-row|list-col-grow|rounded-box|
    (?:bg|text|border|fill|stroke)-base-(?:100|200|300|content)
  )(?=$|[\s"'\/])/x

  @core_component_class_signatures [
    ~r/["']btn["']/,
    ~r/class=["']fieldset(?:\s|["'])/,
    ~r/class=["']label(?:\s|["'])/,
    ~r/["']checkbox checkbox/,
    ~r/["']w-full select["']/,
    ~r/["']w-full textarea["']/,
    ~r/["']w-full input["']/,
    ~r/class=["']table(?:\s|["'])/,
    ~r/class=["']list(?:\s|["'])/
  ]

  @offline_font_sources [
    "assets/css/app.css",
    "lib/emakola_web/controllers/error_html/404.html.heex",
    "lib/emakola_web/controllers/error_html/500.html.heex"
  ]

  @material_symbols_url "https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap"

  test "project-owned UI sources do not reference the removed component plugin" do
    offenders =
      project_ui_files()
      |> matching_lines(~r/daisyui/i)

    assert offenders == [],
           "removed component-plugin references found:\n#{Enum.join(offenders, "\n")}"
  end

  test "project-owned UI sources contain no distinctive component-plugin classes" do
    offenders =
      project_ui_files()
      |> matching_lines(@distinctive_component_classes)

    assert offenders == [],
           "component-plugin classes found; replace them with project Tailwind utilities:\n" <>
             Enum.join(offenders, "\n")

    core_source = File.read!("lib/emakola_web/components/core_components.ex")

    for signature <- @core_component_class_signatures do
      refute core_source =~ signature,
             "core_components.ex contains a removed component class matching #{inspect(signature)}"
    end
  end

  test "global and standalone error typography has no external font dependency" do
    offenders =
      matching_lines(@offline_font_sources, ~r{https://fonts\.(?:googleapis|gstatic)\.com})

    assert offenders == [],
           "offline-safe typography sources contain external font URLs:\n#{Enum.join(offenders, "\n")}"
  end

  test "root layout permits only the temporary Material Symbols font exception" do
    root = File.read!("lib/emakola_web/components/layouts/root.html.heex")

    external_font_urls =
      Regex.scan(~r{https://fonts\.(?:googleapis|gstatic)\.com[^"\s<]*}, root)
      |> List.flatten()

    assert external_font_urls == [
             "https://fonts.googleapis.com",
             "https://fonts.gstatic.com",
             @material_symbols_url
           ]

    refute root =~ "family=Inter"
    refute root =~ "family=Manrope"
    refute root =~ "family=JetBrains+Mono"
  end

  defp project_ui_files do
    @project_ui_globs
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.reject(&String.contains?(&1, "/vendor/"))
  end

  defp matching_lines(files, pattern) do
    Enum.flat_map(files, fn path ->
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _line_number} -> line =~ pattern end)
      |> Enum.map(fn {_line, line_number} -> "#{path}:#{line_number}" end)
    end)
  end
end
