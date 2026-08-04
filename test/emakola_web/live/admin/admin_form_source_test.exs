defmodule EmakolaWeb.AdminFormSourceTest do
  use ExUnit.Case, async: true

  @admin_live_root "lib/emakola_web/live/admin"

  test "admin LiveViews use Phoenix form components instead of raw form tags" do
    offenders =
      @admin_live_root
      |> Path.join("**/*.{ex,heex}")
      |> Path.wildcard()
      |> Enum.filter(fn file ->
        file
        |> File.read!()
        |> String.contains?("<form")
      end)

    assert offenders == [], "raw <form tags found in: #{Enum.join(offenders, ", ")}"
  end
end
