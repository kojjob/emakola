defmodule EmakolaWeb.LiveEventHandlerGuardTest do
  @moduledoc """
  Every `phx-click` must have somebody to answer it.

  A LiveView that receives an event no clause matches does not shrug — it
  crashes, and the merchant loses the page they were on. The catalogue and
  storefront have both been bitten by this, and it is invisible until someone
  clicks the button, which is exactly what a test suite of render assertions
  never does.

  This is a source scan, not a runtime check, so it is cheap enough to run on
  every commit. It found `phx-click="copy"` on the DNS-record button in
  StoreDomainLive: nothing handled it, so tapping the value a merchant needed
  to paste into their registrar copied nothing and took the page down.

  Handlers count whether they are `handle_event/3` clauses or private
  functions attached with `attach_hook(:x, :handle_event, ...)` — the
  notification bell in the sidebar uses the latter, and reading only the
  former makes it look broken when it is not.
  """

  use ExUnit.Case, async: true

  @web_root "lib/emakola_web"

  @event_attrs ~w(click change submit blur focus keyup keydown)

  test "no phx event is pushed at a LiveView that cannot answer it" do
    handled = handled_event_names()

    offenders =
      for {file, event, line} <- pushed_events(),
          event not in handled,
          do: "#{file}:#{line} pushes \"#{event}\""

    assert offenders == [],
           """
           These controls push events nothing handles. Clicking one crashes the
           LiveView and the merchant loses the page:

           #{Enum.join(offenders, "\n")}
           """
  end

  # Every event name a template pushes, skipping the ones that only appear
  # inside @doc examples — core_components documents `phx-click="go"`.
  defp pushed_events do
    attrs = Enum.join(@event_attrs, "|")
    attr_re = ~r/phx-(?:#{attrs})=\{?"([a-z0-9_]+)"/
    push_re = ~r/JS\.push\("([a-z0-9_]+)"/

    for file <- source_files(),
        {line, number} <- code_lines(File.read!(file)),
        re <- [attr_re, push_re],
        [_, event] <- Regex.scan(re, line),
        do: {Path.relative_to(file, @web_root), event, number}
  end

  defp handled_event_names do
    for file <- source_files(),
        source = File.read!(file),
        re <- [~r/def handle_event\(\s*"([a-z0-9_]+)"/, ~r/defp handle_\w+\(\s*"([a-z0-9_]+)"/],
        [_, event] <- Regex.scan(re, source),
        into: MapSet.new(),
        do: event
  end

  defp source_files do
    Path.wildcard(@web_root <> "/**/*.{ex,heex}")
  end

  # Skips @doc and @moduledoc bodies, where core_components documents
  # `phx-click="go"` in an example. Only those: a LiveView's whole template
  # lives in a ~H""" heredoc, so skipping heredocs generally would blind this
  # check to every real phx-click in the app — which it did, on the first
  # draft, and the test passed while the bug was still there.
  defp code_lines(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({[], false}, fn {line, number}, {kept, in_doc?} ->
      cond do
        in_doc? ->
          {kept, not String.contains?(line, ~s("""))}

        Regex.match?(~r/@(?:module)?doc\s+"""/, line) ->
          {kept, true}

        true ->
          {[{line, number} | kept], false}
      end
    end)
    |> elem(0)
  end
end
