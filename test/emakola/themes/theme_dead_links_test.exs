defmodule Emakola.Themes.ThemeDeadLinksTest do
  @moduledoc """
  Source-level guard against themes linking storefront paths that no router
  dialect serves. Same idiom as AdminFormSourceTest: grep the sources, because
  a dead link renders fine and only fails when a customer clicks it.

  Found via the atelier theme linking "/collections" — a page that has never
  existed in any dialect, live in production nav and footer.
  """
  use ExUnit.Case, async: true

  # Every literal store_path target a theme may emit. Parameterised targets
  # (/products/#{...}) are covered by the routes themselves.
  @routable ~w(
    / /products /cart /checkout /about /contact /faq /policies /blog /recipes
    /account /account/downloads /saved-stores /wishlist /login /register
    /whatsapp /auth/customer-logout
  )

  test "themes only link storefront paths that actually route" do
    offenders =
      Path.wildcard("lib/emakola/themes/**/*.ex")
      |> Enum.flat_map(fn file ->
        Regex.scan(~r/store_path\([^,]+,\s*"(\/[a-z\-]*)"\)/, File.read!(file))
        |> Enum.map(fn [_, path] -> {file, path} end)
      end)
      |> Enum.reject(fn {_file, path} -> path in @routable end)

    assert offenders == [],
           "themes link paths with no route (dead links in production): #{inspect(offenders)}"
  end
end
