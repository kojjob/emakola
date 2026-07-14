defmodule EmakolaWeb.PhxValueCollisionTest do
  @moduledoc """
  `phx-value-value` is silently overwritten. Never use it.

  LiveView builds a click's payload in `View.extractMeta/3`
  (deps/phoenix_live_view/assets/js/phoenix_live_view/view.js). It reads every
  `phx-value-*` attribute into the params map, and THEN does:

      if (el.value !== undefined && !(el instanceof HTMLFormElement)) {
        meta.value = el.value;
      }

  Every `<button>` has a `.value` property, defaulting to `""`. So on a button,
  that line lands *after* the `phx-value-*` loop and overwrites `params["value"]`
  with the empty string. Whatever `phx-value-value` said never reaches the server.

  This shipped on all nineteen theme product pages: every variant picker sent
  `%{"option_type_id" => "...", "value" => ""}`, so `find_matching_variant`
  matched nothing and a shopper could not choose a size or a colour on any theme.
  It also shipped on the admin page editor's publish toggle, where
  `published: value == "true"` therefore evaluated `"" == "true"` — the toggle
  could only ever un-publish.

  Not one test caught it, and no test could: `render_click(view, event, params)`
  hands the params straight to `handle_event/3`, and even
  `element(...) |> render_click()` reads `phx-value-*` from the DOM without
  reproducing the `el.value` override. The bug lives in the browser's
  serialization step, which the test harness does not run. It took clicking the
  button in a real browser and reading the server log to see it.

  So this guard is a source scan, not a render assertion. Use a distinct param
  name (`phx-value-option_value_id`, `phx-value-new_value`) and it cannot collide.
  """
  use ExUnit.Case, async: true

  @source_globs ["lib/**/*.ex", "lib/**/*.heex"]

  test "no template uses phx-value-value" do
    offenders =
      @source_globs
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _n} -> String.contains?(line, "phx-value-value") end)
        |> Enum.map(fn {_line, n} -> "#{path}:#{n}" end)
      end)

    assert offenders == [],
           """
           phx-value-value is overwritten by the element's own .value property
           before the event leaves the browser — on a <button> it always arrives
           as "". The server never sees what you set.

           Rename the param to something specific (phx-value-option_value_id,
           phx-value-new_value) and match on that in handle_event/3.

           Offending lines:
           #{Enum.map_join(offenders, "\n", &"  #{&1}")}
           """
  end
end
