defmodule Emakola.Themes.RealPhotoBadgeCoverageTest do
  use ExUnit.Case, async: true

  test "every theme ProductDetail renders the shared RealPhotoBadge" do
    Path.wildcard("lib/emakola/themes/*/product_detail.ex")
    |> Enum.each(fn file ->
      assert File.read!(file) =~ "RealPhotoBadge",
             "#{file} does not render the Real photo badge"
    end)
  end
end
