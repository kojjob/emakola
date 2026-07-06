defmodule Emakola.Cart.CartStoreTest do
  use Emakola.DataCase, async: true

  alias Emakola.Cart.CartItem
  alias Emakola.Cart.CartStore

  setup do
    # Each test gets a unique session_id + store_id to avoid cross-test
    # interference. Carts are scoped by both: one browser session can hold a
    # separate cart per store it visits.
    session_id = Ecto.UUID.generate()
    store_id = Ecto.UUID.generate()
    %{session_id: session_id, store_id: store_id}
  end

  describe "get_cart/2" do
    test "returns empty list for new session", ctx do
      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end
  end

  describe "add_item/3" do
    test "adds a new item to empty cart", ctx do
      item = build_item()

      assert :ok = CartStore.add_item(ctx.session_id, ctx.store_id, item)
      assert [stored_item] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored_item.variant_id == item.variant_id
      assert stored_item.quantity == 1
      assert stored_item.product_title == item.product_title
    end

    test "increments quantity when adding same variant_id twice", ctx do
      item = build_item(quantity: 2)

      CartStore.add_item(ctx.session_id, ctx.store_id, item)
      CartStore.add_item(ctx.session_id, ctx.store_id, %{item | quantity: 3})

      [stored] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored.quantity == 5
    end

    test "adds different items separately", ctx do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "Product A")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Product B")

      CartStore.add_item(ctx.session_id, ctx.store_id, item_a)
      CartStore.add_item(ctx.session_id, ctx.store_id, item_b)

      cart = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert length(cart) == 2
    end

    test "caps quantity at 10 when adding same item repeatedly", ctx do
      item = build_item(quantity: 8)

      CartStore.add_item(ctx.session_id, ctx.store_id, item)
      CartStore.add_item(ctx.session_id, ctx.store_id, %{item | quantity: 5})

      [stored] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored.quantity == 10
    end

    test "same variant added twice stays a single row with summed quantity", ctx do
      item = build_item(quantity: 4)

      CartStore.add_item(ctx.session_id, ctx.store_id, item)
      CartStore.add_item(ctx.session_id, ctx.store_id, %{item | quantity: 3})

      rows = Repo.all(from c in CartItem, where: c.session_id == ^ctx.session_id)
      assert [%CartItem{quantity: 7}] = rows
    end

    test "dedup row is capped at exactly 10", ctx do
      item = build_item(quantity: 9)

      CartStore.add_item(ctx.session_id, ctx.store_id, item)
      CartStore.add_item(ctx.session_id, ctx.store_id, %{item | quantity: 9})

      rows = Repo.all(from c in CartItem, where: c.session_id == ^ctx.session_id)
      assert [%CartItem{quantity: 10}] = rows
    end

    test "increment refreshes snapshot fields from the new item map", ctx do
      item = build_item(product_title: "Old Title", unit_price: 5000)

      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      CartStore.add_item(ctx.session_id, ctx.store_id, %{
        item
        | product_title: "New Title",
          unit_price: 6000
      })

      assert [%{product_title: "New Title", unit_price: 6000}] =
               CartStore.get_cart(ctx.session_id, ctx.store_id)
    end
  end

  describe "update_quantity/4" do
    test "updates quantity of existing item", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      assert :ok = CartStore.update_quantity(ctx.session_id, ctx.store_id, item.variant_id, 5)

      [stored] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored.quantity == 5
    end

    test "removes item when quantity is set to 0", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      CartStore.update_quantity(ctx.session_id, ctx.store_id, item.variant_id, 0)

      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end

    test "removes item when quantity is negative", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      CartStore.update_quantity(ctx.session_id, ctx.store_id, item.variant_id, -1)

      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end

    test "caps quantity at 10", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      CartStore.update_quantity(ctx.session_id, ctx.store_id, item.variant_id, 15)

      [stored] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored.quantity == 10
    end

    test "setting quantity to exactly 10 keeps 10", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      CartStore.update_quantity(ctx.session_id, ctx.store_id, item.variant_id, 10)

      [stored] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert stored.quantity == 10
    end

    test "returns :ok even for non-existent variant_id", ctx do
      assert :ok =
               CartStore.update_quantity(ctx.session_id, ctx.store_id, Ecto.UUID.generate(), 5)
    end

    test "preserves insertion order after a quantity update", ctx do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "First")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Second")

      CartStore.add_item(ctx.session_id, ctx.store_id, item_a)
      CartStore.add_item(ctx.session_id, ctx.store_id, item_b)

      # Updating the first item bumps its updated_at; ordering must follow
      # inserted_at, so "First" stays first.
      CartStore.update_quantity(ctx.session_id, ctx.store_id, item_a.variant_id, 5)

      assert [%{product_title: "First"}, %{product_title: "Second"}] =
               CartStore.get_cart(ctx.session_id, ctx.store_id)
    end
  end

  describe "remove_item/3" do
    test "removes item from cart", ctx do
      item = build_item()
      CartStore.add_item(ctx.session_id, ctx.store_id, item)

      assert :ok = CartStore.remove_item(ctx.session_id, ctx.store_id, item.variant_id)
      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end

    test "does not affect other items", ctx do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "Keep Me")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Remove Me")

      CartStore.add_item(ctx.session_id, ctx.store_id, item_a)
      CartStore.add_item(ctx.session_id, ctx.store_id, item_b)

      CartStore.remove_item(ctx.session_id, ctx.store_id, item_b.variant_id)

      cart = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert length(cart) == 1
      assert hd(cart).product_title == "Keep Me"
    end

    test "returns :ok for non-existent variant_id", ctx do
      assert :ok = CartStore.remove_item(ctx.session_id, ctx.store_id, Ecto.UUID.generate())
    end
  end

  describe "clear_cart/2" do
    test "empties the cart", ctx do
      CartStore.add_item(
        ctx.session_id,
        ctx.store_id,
        build_item(variant_id: Ecto.UUID.generate())
      )

      CartStore.add_item(
        ctx.session_id,
        ctx.store_id,
        build_item(variant_id: Ecto.UUID.generate())
      )

      assert :ok = CartStore.clear_cart(ctx.session_id, ctx.store_id)
      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end

    test "returns :ok for already empty cart", ctx do
      assert :ok = CartStore.clear_cart(ctx.session_id, ctx.store_id)
    end
  end

  describe "cart_count/2" do
    test "returns 0 for empty cart", ctx do
      assert CartStore.cart_count(ctx.session_id, ctx.store_id) == 0
    end

    test "returns 0 for a session that was never seen" do
      assert CartStore.cart_count(Ecto.UUID.generate(), Ecto.UUID.generate()) == 0
    end

    test "returns total quantity across all items", ctx do
      CartStore.add_item(
        ctx.session_id,
        ctx.store_id,
        build_item(variant_id: Ecto.UUID.generate(), quantity: 2)
      )

      CartStore.add_item(
        ctx.session_id,
        ctx.store_id,
        build_item(variant_id: Ecto.UUID.generate(), quantity: 3)
      )

      assert CartStore.cart_count(ctx.session_id, ctx.store_id) == 5
    end

    test "updates after add/remove", ctx do
      item = build_item(quantity: 2)
      CartStore.add_item(ctx.session_id, ctx.store_id, item)
      assert CartStore.cart_count(ctx.session_id, ctx.store_id) == 2

      CartStore.remove_item(ctx.session_id, ctx.store_id, item.variant_id)
      assert CartStore.cart_count(ctx.session_id, ctx.store_id) == 0
    end
  end

  describe "session isolation" do
    test "different sessions have separate carts", ctx do
      session_a = Ecto.UUID.generate()
      session_b = Ecto.UUID.generate()

      CartStore.add_item(session_a, ctx.store_id, build_item(product_title: "Session A Item"))
      CartStore.add_item(session_b, ctx.store_id, build_item(product_title: "Session B Item"))

      cart_a = CartStore.get_cart(session_a, ctx.store_id)
      cart_b = CartStore.get_cart(session_b, ctx.store_id)

      assert length(cart_a) == 1
      assert length(cart_b) == 1
      assert hd(cart_a).product_title == "Session A Item"
      assert hd(cart_b).product_title == "Session B Item"
    end
  end

  describe "store isolation" do
    test "the same browser session keeps a separate cart per store", %{session_id: session_id} do
      store_a = Ecto.UUID.generate()
      store_b = Ecto.UUID.generate()

      CartStore.add_item(session_id, store_a, build_item(product_title: "Store A Item"))
      CartStore.add_item(session_id, store_b, build_item(product_title: "Store B Item"))

      cart_a = CartStore.get_cart(session_id, store_a)
      cart_b = CartStore.get_cart(session_id, store_b)

      assert length(cart_a) == 1
      assert length(cart_b) == 1
      assert hd(cart_a).product_title == "Store A Item"
      assert hd(cart_b).product_title == "Store B Item"
    end

    test "the same variant added in two stores stays two separate rows", %{session_id: session_id} do
      store_a = Ecto.UUID.generate()
      store_b = Ecto.UUID.generate()
      shared_variant = Ecto.UUID.generate()

      CartStore.add_item(session_id, store_a, build_item(variant_id: shared_variant, quantity: 2))
      CartStore.add_item(session_id, store_b, build_item(variant_id: shared_variant, quantity: 3))

      assert [%{quantity: 2}] = CartStore.get_cart(session_id, store_a)
      assert [%{quantity: 3}] = CartStore.get_cart(session_id, store_b)
    end

    test "cart_count is scoped per store", %{session_id: session_id} do
      store_a = Ecto.UUID.generate()
      store_b = Ecto.UUID.generate()

      CartStore.add_item(session_id, store_a, build_item(quantity: 2))
      CartStore.add_item(session_id, store_b, build_item(quantity: 5))

      assert CartStore.cart_count(session_id, store_a) == 2
      assert CartStore.cart_count(session_id, store_b) == 5
    end

    test "clearing one store's cart leaves the other store's cart intact", %{
      session_id: session_id
    } do
      store_a = Ecto.UUID.generate()
      store_b = Ecto.UUID.generate()

      CartStore.add_item(session_id, store_a, build_item())
      CartStore.add_item(session_id, store_b, build_item())

      CartStore.clear_cart(session_id, store_a)

      assert CartStore.get_cart(session_id, store_a) == []
      assert length(CartStore.get_cart(session_id, store_b)) == 1
    end
  end

  describe "expiry" do
    test "items have a stored_at timestamp", ctx do
      CartStore.add_item(ctx.session_id, ctx.store_id, build_item())

      [item] = CartStore.get_cart(ctx.session_id, ctx.store_id)
      assert %DateTime{} = item.stored_at
    end

    test "cleanup_expired/1 removes carts older than given seconds", ctx do
      CartStore.add_item(ctx.session_id, ctx.store_id, build_item())

      backdate_session(ctx.session_id, 90_000)

      # Cleanup carts older than 24 hours (86400 seconds)
      CartStore.cleanup_expired(86_400)

      assert CartStore.get_cart(ctx.session_id, ctx.store_id) == []
    end

    test "cleanup_expired/1 preserves fresh carts", ctx do
      fresh_session = Ecto.UUID.generate()
      CartStore.add_item(fresh_session, ctx.store_id, build_item())

      CartStore.cleanup_expired(86_400)

      assert length(CartStore.get_cart(fresh_session, ctx.store_id)) == 1
    end

    test "cleanup_expired/1 keeps the whole cart when its newest item is fresh", ctx do
      old_item = build_item(variant_id: Ecto.UUID.generate())
      CartStore.add_item(ctx.session_id, ctx.store_id, old_item)
      backdate_session(ctx.session_id, 90_000)

      fresh_item = build_item(variant_id: Ecto.UUID.generate())
      CartStore.add_item(ctx.session_id, ctx.store_id, fresh_item)

      CartStore.cleanup_expired(86_400)

      # Newest-item semantics: one fresh item keeps the old one alive too
      assert length(CartStore.get_cart(ctx.session_id, ctx.store_id)) == 2
    end

    test "cleanup_expired/1 leaves other sessions untouched", ctx do
      stale_session = ctx.session_id
      fresh_session = Ecto.UUID.generate()

      CartStore.add_item(stale_session, ctx.store_id, build_item())
      backdate_session(stale_session, 90_000)
      CartStore.add_item(fresh_session, ctx.store_id, build_item())

      CartStore.cleanup_expired(86_400)

      assert CartStore.get_cart(stale_session, ctx.store_id) == []
      assert length(CartStore.get_cart(fresh_session, ctx.store_id)) == 1
    end

    test "cleanup_expired/1 expires each store's cart independently", %{session_id: session_id} do
      stale_store = Ecto.UUID.generate()
      fresh_store = Ecto.UUID.generate()

      CartStore.add_item(session_id, stale_store, build_item())
      backdate_session(session_id, 90_000)
      CartStore.add_item(session_id, fresh_store, build_item())

      CartStore.cleanup_expired(86_400)

      assert CartStore.get_cart(session_id, stale_store) == []
      assert length(CartStore.get_cart(session_id, fresh_store)) == 1
    end
  end

  describe "init/0" do
    test "is a compatibility no-op returning :ok" do
      assert CartStore.init() == :ok
    end
  end

  # -- Helpers --

  defp build_item(overrides \\ []) do
    %{
      variant_id: Keyword.get(overrides, :variant_id, Ecto.UUID.generate()),
      product_title: Keyword.get(overrides, :product_title, "Test Product"),
      variant_info: Keyword.get(overrides, :variant_info, "Default"),
      unit_price: Keyword.get(overrides, :unit_price, 5000),
      quantity: Keyword.get(overrides, :quantity, 1),
      sku: Keyword.get(overrides, :sku, "TST-001")
    }
  end

  # Force a session's items to look old (replaces the old direct ETS write)
  defp backdate_session(session_id, seconds_ago) do
    old = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    Repo.update_all(
      from(c in CartItem, where: c.session_id == ^session_id),
      set: [inserted_at: old, updated_at: old]
    )
  end
end
