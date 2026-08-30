defmodule EmakolaWeb.Storefront.SharedPageThemeVarsTest do
  @moduledoc """
  Shared pages must define every CSS variable the theme's chrome references.

  Theme navs/footers color themselves with `var(--<theme>-*)` custom
  properties that the theme's own pages define via a `theme_styles/1`
  `<style>` block. Shared pages (cart, checkout, …) render the same chrome
  through `DefaultRenderers.Chrome` but never injected that block — so on the
  cart page Akwaaba's and Heirloom's footers lost their dark background and
  rendered white-on-white, a ~500px unreadable dead zone on the money path.

  The rule: any `var(--x)` referenced WITHOUT a fallback on the cart page must
  have a `--x:` definition somewhere in the same document.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  # var(--name) with no fallback — a comma would mean a fallback exists.
  @var_reference ~r/var\(\s*--([a-zA-Z0-9_-]+)\s*\)/
  @var_definition ~r/--([a-zA-Z0-9_-]+)\s*:/

  defp undefined_vars(html) do
    referenced =
      @var_reference
      |> Regex.scan(html, capture: :all_but_first)
      |> MapSet.new(fn [name] -> name end)

    defined =
      @var_definition
      |> Regex.scan(html, capture: :all_but_first)
      |> MapSet.new(fn [name] -> name end)

    MapSet.difference(referenced, defined)
  end

  defp store_on_theme!(theme_id) do
    store = Factory.create_store!(%{currency: "GHS"})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => theme_id}})
    |> Ash.update!(authorize?: false)
  end

  describe "merchant overrides reach shared pages" do
    test "a merchant's primary color override paints the cart page chrome", %{conn: conn} do
      store = store_on_theme!("chale")

      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{"theme" => "chale", "colors" => %{"primary" => "#1A2B3C"}}
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      primaries =
        ~r/--theme-primary:\s*(#[0-9A-Fa-f]{3,8})/
        |> Regex.scan(html, capture: :all_but_first)
        |> List.flatten()

      assert primaries != [] and Enum.all?(primaries, &(&1 == "#1A2B3C")),
             "the merchant picked #1A2B3C, but a later --theme-primary definition " <>
               "(#{inspect(Enum.uniq(primaries))}) still paints the theme default — " <>
               "the theme's chrome-injected theme_styles renders with an empty theme " <>
               "map and overrides the layout's correct value; Chrome must pass the " <>
               "resolved theme through"
    end
  end

  for theme_id <- ThemeResolver.theme_ids() do
    test "#{theme_id}: the cart page defines every CSS variable it references", %{conn: conn} do
      store = store_on_theme!(unquote(theme_id))

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      missing = undefined_vars(html)

      assert MapSet.size(missing) == 0,
             "#{unquote(theme_id)} /cart references CSS variables with no definition and " <>
               "no fallback — the styled element silently loses that property (this is how " <>
               "Akwaaba's cart footer went white-on-white): #{Enum.join(missing, ", ")}"
    end
  end
end
