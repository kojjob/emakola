defmodule EmakolaWeb.Storefront.VariantPickerTest do
  @moduledoc """
  Picking a size or colour must select it, on every theme.

  Two separate bugs met here.

  Fresh and Bold sent `phx-value-type` — the option type's NAME — and the value's
  display string. Neither param matched `handle_event/3`, which has no catch-all,
  so choosing a size on a Fresh or Bold product page raised FunctionClauseError
  and killed the page.

  The other seventeen themes looked correct and were not. They sent
  `phx-value-value`, which LiveView overwrites with the element's own `.value`
  property before the event leaves the browser — and a `<button>`'s `.value` is
  `""`. So every theme's variant picker sent an empty value and NO shopper could
  select a size or colour on ANY theme. The param is `option_value_id` now.
  See EmakolaWeb.PhxValueCollisionTest; that bug is invisible to this test,
  because render_click does not run the browser's serialization step.
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

        # No `if` guard here. The seeded product always has an option type with
        # two values, so every theme must render a picker for it. These
        # assertions used to sit inside `if html =~ select_option`, which meant
        # a theme rendering no picker AT ALL skipped every one of them and
        # passed — which is exactly how Akwaaba shipped a product page where no
        # variant can be chosen.
        assert html =~ ~s(phx-click="select_option"),
               "the #{@theme} product page renders no variant picker, so a shopper " <>
                 "cannot choose a size or colour and add_to_cart can only ever add " <>
                 "the default variant"

        assert has_element?(
                 view,
                 ~s([phx-click="select_option"][phx-value-option_type_id="#{ctx.option_type.id}"][phx-value-option_value_id="#{ctx.large.id}"])
               ),
               "the #{@theme} variant picker does not send option_type_id + the value's id"

        # Would raise FunctionClauseError and kill the page before the fix.
        selected =
          render_click(view, "select_option", %{
            "option_type_id" => ctx.option_type.id,
            "option_value_id" => ctx.large.id
          })

        assert selected =~ "Large"
      end
    end
  end
end
