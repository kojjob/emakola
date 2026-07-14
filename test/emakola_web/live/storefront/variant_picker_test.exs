defmodule EmakolaWeb.Storefront.VariantPickerTest do
  @moduledoc """
  Picking a size or colour must select it, on every theme.

  `ProductDetailLive.handle_event/3` matches `select_option` on
  `%{"option_type_id" => _, "value" => _}`, and `selected_options` maps an option
  type's id to an option *value's id*. Fresh and Bold sent `phx-value-type`
  (the option type's NAME) and the value's display string instead — so neither
  param matched, `handle_event/3` fell through with no catch-all clause, and
  choosing a size on a Fresh or Bold product page raised FunctionClauseError and
  killed the page.

  Asserted across every theme, because the seventeen that were right are what
  made the two that were wrong invisible.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()

  defp seed(theme) do
    store = Emakola.Factory.create_store!(%{theme_config: %{"theme" => theme}})
    product = Emakola.Factory.create_product!(store, %{title: "Kente Shirt", status: :active})

    option_type =
      Emakola.Factory.create_option_type!(product, store, %{name: "Size", position: 1})

    small = Emakola.Factory.create_option_value!(option_type, store, %{value: "Small"})
    large = Emakola.Factory.create_option_value!(option_type, store, %{value: "Large"})

    Emakola.Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})

    %{store: store, product: product, option_type: option_type, small: small, large: large}
  end

  describe "the variant picker sends what the handler matches on" do
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        if html =~ ~s(phx-click="select_option") do
          assert has_element?(
                   view,
                   ~s([phx-click="select_option"][phx-value-option_type_id="#{ctx.option_type.id}"][phx-value-value="#{ctx.large.id}"])
                 ),
                 "the #{@theme} variant picker does not send option_type_id + the value's id"

          # Would raise FunctionClauseError and kill the page before the fix.
          selected =
            render_click(view, "select_option", %{
              "option_type_id" => ctx.option_type.id,
              "value" => ctx.large.id
            })

          assert selected =~ "Large"
        end
      end
    end
  end
end
