defmodule EmakolaWeb.Assets.ColocatedHooksTest do
  @moduledoc """
  Colocated hooks (`<script :type={Phoenix.LiveView.ColocatedHook}>`) are
  extracted at compile time into `_build/phoenix-colocated` and only run in
  the browser if app.js hands them to the LiveSocket. Nothing in ExUnit
  exercises the browser, so for weeks every colocated hook was dead and
  every test stayed green. These checks read the source, not the DOM.
  """
  use ExUnit.Case, async: true

  @app_js Path.expand("../../../assets/js/app.js", __DIR__)
  @web_dir Path.expand("../../../lib/emakola_web", __DIR__)

  test "app.js imports the colocated hooks and hands them to the LiveSocket" do
    app_js = File.read!(@app_js)

    assert app_js =~
             ~r/import\s+\{\s*hooks\s+as\s+colocatedHooks\s*\}\s+from\s+"phoenix-colocated\/emakola"/,
           "app.js must import {hooks as colocatedHooks} from \"phoenix-colocated/emakola\""

    assert app_js =~ ~r/hooks:\s*\{\s*\.\.\.colocatedHooks/,
           "app.js must spread colocatedHooks into the LiveSocket hooks map"
  end

  test "every phx-hook=\".Name\" is declared as a colocated hook in the same module" do
    missing =
      for file <- Path.wildcard(Path.join(@web_dir, "**/*.ex")),
          source = File.read!(file),
          [_, name] <- Regex.scan(~r/phx-hook="\.([A-Za-z0-9_]+)"/, source),
          not (source =~ ~r/name="\.#{name}"/),
          do: {Path.relative_to(file, @web_dir), name}

    assert missing == [],
           "phx-hook=\".Name\" used without a colocated <script name=\".Name\"> in the same file: #{inspect(missing)}"
  end
end
