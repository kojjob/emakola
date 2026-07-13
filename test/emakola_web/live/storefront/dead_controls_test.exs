defmodule EmakolaWeb.Storefront.DeadControlsTest do
  @moduledoc """
  Clicks the controls a shopper actually sees.

  The existing add-to-cart tests fire `render_click(view, "add_to_cart", ...)`
  straight at the handler, so they passed for a theme whose "Add to bag" pill
  was a `<span>` — the handler was never the broken part. The same blind spot
  hid six newsletter forms that carried no `phx-submit` at all.

  Every test here drives the rendered element: `element/2` and `form/3` fail
  when the selector matches nothing, and `render_click/1` fails when the
  element carries no `phx-click`. A dead control cannot pass these.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Emakola.Cart.CartStore
  alias Emakola.Factory

  setup %{conn: conn} do
    session_id = Ecto.UUID.generate()
    %{conn: init_test_session(conn, %{"cart_session_id" => session_id}), session_id: session_id}
  end

  defp store_on(theme) do
    Factory.create_store!(%{theme_config: %{"theme" => theme}})
  end

  defp stocked_product!(store, stock \\ 10) do
    product = Factory.create_product!(store, %{status: :active})
    Factory.create_variant!(product, store, %{price: 5000, stock_quantity: stock})
    product
  end

  describe "Vibrant featured card" do
    test "the 'Add to bag' button adds the featured product to the bag", ctx do
      %{conn: conn, session_id: session_id} = ctx
      store = store_on("vibrant")
      product = stocked_product!(store)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      view
      |> element(~s(button[phx-click="add_to_cart"][phx-value-product-id="#{product.id}"]))
      |> render_click()

      assert [item] = CartStore.get_cart(session_id, store.id)
      assert item.product_title == product.title
      assert item.quantity == 1
    end

    test "a sold-out featured product offers no button to press", ctx do
      store = store_on("vibrant")
      _product = stocked_product!(store, 0)

      {:ok, _view, html} = live(ctx.conn, "/s/#{store.slug}")

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
    end
  end

  describe "newsletter forms" do
    # The six themes whose forms captured nothing, plus Market as the control
    # that was already wired.
    for theme <- ~w(beauty electronics fashion home_living pharmacy spotlight market) do
      test "#{theme}: subscribing actually records a subscriber", ctx do
        store = store_on(unquote(theme))
        _product = stocked_product!(store)

        {:ok, view, _html} = live(ctx.conn, "/s/#{store.slug}")

        html =
          view
          |> form(~s(form[phx-submit="subscribe_newsletter"]), %{"email" => "ama@example.com"})
          |> render_submit()

        assert html =~ "Thanks for subscribing"

        assert [subscriber] =
                 Emakola.Customers.NewsletterSubscriber
                 |> Ash.Query.filter(store_id == ^store.id)
                 |> Ash.read!(authorize?: false)

        assert to_string(subscriber.email) == "ama@example.com"
      end
    end
  end
end
