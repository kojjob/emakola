defmodule EmakolaWeb.Storefront.QuickAdd do
  @moduledoc """
  The storefront's "add this product straight to the cart" action.

  Product cards are theme chrome: the same card renders on the home page
  (`StoreLive`), the category page (`CategoryLive`) and the product list
  (`ProductListLive`). The first two each carried their own copy of this
  handler; the product list carried none, so the identical button that worked on
  the home page raised `FunctionClauseError` on /products, killed the LiveView
  and reset the page under the shopper.

  One implementation, three call sites, so a page cannot silently lack it again.

  The product is always re-fetched and scoped to `socket.assigns.store` — the
  client sends only an id, and a product belonging to another store must not be
  addable to this store's cart.
  """

  import Phoenix.LiveView, only: [put_flash: 3]
  import Phoenix.Component, only: [assign: 3]

  alias Emakola.Cart.CartStore

  @doc """
  Adds the product's first in-stock variant to the cart and refreshes the count.

  Returns the standard `{:noreply, socket}` so a `handle_event/3` clause can
  delegate to it directly.
  """
  def add_to_cart(socket, product_id) do
    store = socket.assigns.store

    with {:ok, product} <-
           Emakola.Catalog.get_active_product(store.id, product_id, authorize?: false),
         product = Ash.load!(product, [:variants, :images], authorize?: false),
         variant when not is_nil(variant) <- default_variant(product),
         true <- Emakola.Catalog.Variant.in_stock?(variant) do
      CartStore.add_item(socket.assigns.cart_session_id, store.id, %{
        variant_id: variant.id,
        quantity: 1,
        product_title: product.title,
        # The quick-add always takes the default variant, so there is no
        # option choice to describe — and a SKU is not a customer-facing label.
        variant_info: "",
        unit_price: variant.price,
        sku: variant.sku,
        image_url: primary_image_url(product)
      })

      {:noreply,
       socket
       |> assign(:cart_count, CartStore.cart_count(socket.assigns.cart_session_id, store.id))
       |> put_flash(:info, "#{product.title} added to cart")}
    else
      # A product with no variant, or whose only variant is sold out. Both are
      # "you cannot buy this right now", which is what the shopper needs to know.
      nil -> {:noreply, put_flash(socket, :error, "This product is out of stock")}
      false -> {:noreply, put_flash(socket, :error, "This product is out of stock")}
      _ -> {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  defp default_variant(product) do
    product.variants |> Enum.sort_by(& &1.position) |> List.first()
  end

  defp primary_image_url(product) do
    case product.images do
      [image | _] -> image.thumbnail_url || image.url
      _ -> nil
    end
  end
end
