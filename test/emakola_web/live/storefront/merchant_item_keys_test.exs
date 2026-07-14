defmodule EmakolaWeb.Storefront.MerchantItemKeysTest do
  @moduledoc """
  A merchant's own section content must render, not 500.

  Theme defaults are atom-keyed Elixir literals. But a merchant's `theme_config`
  is persisted to a jsonb column, so THEIR overrides come back **string-keyed**
  — `%{"label" => "..."}`, never `%{label: "..."}`. There is no path by which a
  persisted item is atom-keyed.

  Sections that reach into those items with dot access (`item.label`) therefore
  raise `KeyError` — a 500 on the storefront — the moment a merchant actually
  fills the section in. The theme defaults never trigger it, so the bug is
  invisible until a real merchant customises their shop, and then it is total:
  Pharmacy's stats strip renders *only* when the merchant supplies items, so it
  500s on every store that uses it and never on a default.

  `Emakola.Themes.Item` reads either key shape and treats "" as absent. Every
  section that renders merchant-settable items must go through it.

  These tests write the config exactly as the database returns it — string keys,
  all the way down — which is the whole point. A test that seeds atom-keyed
  inner maps proves nothing, because that is not a state the app can be in.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # {theme, section config as jsonb returns it, the merchant's own words}
  @merchant_sections [
    {"pharmacy",
     %{
       "stats" => %{
         "items" => [%{"icon" => "medication", "value" => "12", "label" => "Years in Osu"}]
       }
     }, ["12", "Years in Osu"]},
    {"home_living",
     %{
       "trust" => %{
         "items" => [
           %{
             "icon" => "local_shipping",
             "label" => "Same-day in Accra",
             "subtitle" => "Order before noon"
           }
         ]
       }
     }, ["Same-day in Accra", "Order before noon"]},
    {"home_living",
     %{
       "sale_band" => %{
         "items" => [
           %{"icon" => "percent", "title" => "Harmattan sale", "subtitle" => "Up to 30% off"}
         ]
       }
     }, ["Harmattan sale", "Up to 30% off"]},
    {"home_living", %{"rooms" => %{"items" => [%{"icon" => "chair", "name" => "Veranda"}]}},
     ["Veranda"]},
    {"beauty",
     %{
       "faq" => %{
         "items" => [
           %{"question" => "Do you deliver to Kumasi?", "answer" => "Yes, within two days."}
         ]
       }
     }, ["Do you deliver to Kumasi?", "Yes, within two days."]},
    {"electronics",
     %{"categories_strip" => %{"items" => [%{"label" => "Power banks", "active" => true}]}},
     ["Power banks"]}
  ]

  for {theme, config, expected} <- @merchant_sections do
    @theme theme
    @config config
    @expected expected

    section = config |> Map.keys() |> List.first()

    test "#{theme}: a merchant's own #{section} items render", %{conn: conn} do
      store =
        Emakola.Factory.create_store!(%{
          theme_config: Map.merge(%{"theme" => @theme}, @config)
        })

      # The crash is a KeyError raised during render, which surfaces here as the
      # LiveView failing to mount at all.
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      for text <- @expected do
        assert html =~ text,
               "the #{@theme} storefront dropped the merchant's own content: #{inspect(text)}"
      end
    end
  end
end
