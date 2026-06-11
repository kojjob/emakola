defmodule Emakola.Cart.CartStoreTest do
  use Emakola.DataCase, async: true

  alias Emakola.Cart.CartItem
  alias Emakola.Cart.CartStore

  setup do
    # Each test gets a unique session_id to avoid cross-test interference
    session_id = Ecto.UUID.generate()
    %{session_id: session_id}
  end

  describe "get_cart/1" do
    test "returns empty list for new session", %{session_id: session_id} do
      assert CartStore.get_cart(session_id) == []
    end
  end

  describe "add_item/2" do
    test "adds a new item to empty cart", %{session_id: session_id} do
      item = build_item()

      assert :ok = CartStore.add_item(session_id, item)
      assert [stored_item] = CartStore.get_cart(session_id)
      assert stored_item.variant_id == item.variant_id
      assert stored_item.quantity == 1
      assert stored_item.product_title == item.product_title
    end

    test "increments quantity when adding same variant_id twice", %{session_id: session_id} do
      item = build_item(quantity: 2)

      CartStore.add_item(session_id, item)
      CartStore.add_item(session_id, %{item | quantity: 3})

      [stored] = CartStore.get_cart(session_id)
      assert stored.quantity == 5
    end

    test "adds different items separately", %{session_id: session_id} do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "Product A")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Product B")

      CartStore.add_item(session_id, item_a)
      CartStore.add_item(session_id, item_b)

      cart = CartStore.get_cart(session_id)
      assert length(cart) == 2
    end

    test "caps quantity at 10 when adding same item repeatedly", %{session_id: session_id} do
      item = build_item(quantity: 8)

      CartStore.add_item(session_id, item)
      CartStore.add_item(session_id, %{item | quantity: 5})

      [stored] = CartStore.get_cart(session_id)
      assert stored.quantity == 10
    end

    test "same variant added twice stays a single row with summed quantity", %{
      session_id: session_id
    } do
      item = build_item(quantity: 4)

      CartStore.add_item(session_id, item)
      CartStore.add_item(session_id, %{item | quantity: 3})

      rows = Repo.all(from c in CartItem, where: c.session_id == ^session_id)
      assert [%CartItem{quantity: 7}] = rows
    end

    test "dedup row is capped at exactly 10", %{session_id: session_id} do
      item = build_item(quantity: 9)

      CartStore.add_item(session_id, item)
      CartStore.add_item(session_id, %{item | quantity: 9})

      rows = Repo.all(from c in CartItem, where: c.session_id == ^session_id)
      assert [%CartItem{quantity: 10}] = rows
    end

    test "increment refreshes snapshot fields from the new item map", %{session_id: session_id} do
      item = build_item(product_title: "Old Title", unit_price: 5000)

      CartStore.add_item(session_id, item)
      CartStore.add_item(session_id, %{item | product_title: "New Title", unit_price: 6000})

      assert [%{product_title: "New Title", unit_price: 6000}] = CartStore.get_cart(session_id)
    end
  end

  describe "update_quantity/3" do
    test "updates quantity of existing item", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      assert :ok = CartStore.update_quantity(session_id, item.variant_id, 5)

      [stored] = CartStore.get_cart(session_id)
      assert stored.quantity == 5
    end

    test "removes item when quantity is set to 0", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      CartStore.update_quantity(session_id, item.variant_id, 0)

      assert CartStore.get_cart(session_id) == []
    end

    test "removes item when quantity is negative", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      CartStore.update_quantity(session_id, item.variant_id, -1)

      assert CartStore.get_cart(session_id) == []
    end

    test "caps quantity at 10", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      CartStore.update_quantity(session_id, item.variant_id, 15)

      [stored] = CartStore.get_cart(session_id)
      assert stored.quantity == 10
    end

    test "setting quantity to exactly 10 keeps 10", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      CartStore.update_quantity(session_id, item.variant_id, 10)

      [stored] = CartStore.get_cart(session_id)
      assert stored.quantity == 10
    end

    test "returns :ok even for non-existent variant_id", %{session_id: session_id} do
      assert :ok = CartStore.update_quantity(session_id, Ecto.UUID.generate(), 5)
    end

    test "preserves insertion order after a quantity update", %{session_id: session_id} do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "First")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Second")

      CartStore.add_item(session_id, item_a)
      CartStore.add_item(session_id, item_b)

      # Updating the first item bumps its updated_at; ordering must follow
      # inserted_at, so "First" stays first.
      CartStore.update_quantity(session_id, item_a.variant_id, 5)

      assert [%{product_title: "First"}, %{product_title: "Second"}] =
               CartStore.get_cart(session_id)
    end
  end

  describe "remove_item/2" do
    test "removes item from cart", %{session_id: session_id} do
      item = build_item()
      CartStore.add_item(session_id, item)

      assert :ok = CartStore.remove_item(session_id, item.variant_id)
      assert CartStore.get_cart(session_id) == []
    end

    test "does not affect other items", %{session_id: session_id} do
      item_a = build_item(variant_id: Ecto.UUID.generate(), product_title: "Keep Me")
      item_b = build_item(variant_id: Ecto.UUID.generate(), product_title: "Remove Me")

      CartStore.add_item(session_id, item_a)
      CartStore.add_item(session_id, item_b)

      CartStore.remove_item(session_id, item_b.variant_id)

      cart = CartStore.get_cart(session_id)
      assert length(cart) == 1
      assert hd(cart).product_title == "Keep Me"
    end

    test "returns :ok for non-existent variant_id", %{session_id: session_id} do
      assert :ok = CartStore.remove_item(session_id, Ecto.UUID.generate())
    end
  end

  describe "clear_cart/1" do
    test "empties the cart", %{session_id: session_id} do
      CartStore.add_item(session_id, build_item(variant_id: Ecto.UUID.generate()))
      CartStore.add_item(session_id, build_item(variant_id: Ecto.UUID.generate()))

      assert :ok = CartStore.clear_cart(session_id)
      assert CartStore.get_cart(session_id) == []
    end

    test "returns :ok for already empty cart", %{session_id: session_id} do
      assert :ok = CartStore.clear_cart(session_id)
    end
  end

  describe "cart_count/1" do
    test "returns 0 for empty cart", %{session_id: session_id} do
      assert CartStore.cart_count(session_id) == 0
    end

    test "returns 0 for a session that was never seen" do
      assert CartStore.cart_count(Ecto.UUID.generate()) == 0
    end

    test "returns total quantity across all items", %{session_id: session_id} do
      CartStore.add_item(session_id, build_item(variant_id: Ecto.UUID.generate(), quantity: 2))
      CartStore.add_item(session_id, build_item(variant_id: Ecto.UUID.generate(), quantity: 3))

      assert CartStore.cart_count(session_id) == 5
    end

    test "updates after add/remove", %{session_id: session_id} do
      item = build_item(quantity: 2)
      CartStore.add_item(session_id, item)
      assert CartStore.cart_count(session_id) == 2

      CartStore.remove_item(session_id, item.variant_id)
      assert CartStore.cart_count(session_id) == 0
    end
  end

  describe "session isolation" do
    test "different sessions have separate carts" do
      session_a = Ecto.UUID.generate()
      session_b = Ecto.UUID.generate()

      CartStore.add_item(session_a, build_item(product_title: "Session A Item"))
      CartStore.add_item(session_b, build_item(product_title: "Session B Item"))

      cart_a = CartStore.get_cart(session_a)
      cart_b = CartStore.get_cart(session_b)

      assert length(cart_a) == 1
      assert length(cart_b) == 1
      assert hd(cart_a).product_title == "Session A Item"
      assert hd(cart_b).product_title == "Session B Item"
    end
  end

  describe "expiry" do
    test "items have a stored_at timestamp", %{session_id: session_id} do
      CartStore.add_item(session_id, build_item())

      [item] = CartStore.get_cart(session_id)
      assert %DateTime{} = item.stored_at
    end

    test "cleanup_expired/1 removes carts older than given seconds", %{session_id: session_id} do
      CartStore.add_item(session_id, build_item())

      backdate_session(session_id, 90_000)

      # Cleanup carts older than 24 hours (86400 seconds)
      CartStore.cleanup_expired(86_400)

      assert CartStore.get_cart(session_id) == []
    end

    test "cleanup_expired/1 preserves fresh carts" do
      fresh_session = Ecto.UUID.generate()
      CartStore.add_item(fresh_session, build_item())

      CartStore.cleanup_expired(86_400)

      assert length(CartStore.get_cart(fresh_session)) == 1
    end

    test "cleanup_expired/1 keeps the whole cart when its newest item is fresh", %{
      session_id: session_id
    } do
      old_item = build_item(variant_id: Ecto.UUID.generate())
      CartStore.add_item(session_id, old_item)
      backdate_session(session_id, 90_000)

      fresh_item = build_item(variant_id: Ecto.UUID.generate())
      CartStore.add_item(session_id, fresh_item)

      CartStore.cleanup_expired(86_400)

      # Newest-item semantics: one fresh item keeps the old one alive too
      assert length(CartStore.get_cart(session_id)) == 2
    end

    test "cleanup_expired/1 leaves other sessions untouched", %{session_id: stale_session} do
      fresh_session = Ecto.UUID.generate()

      CartStore.add_item(stale_session, build_item())
      backdate_session(stale_session, 90_000)
      CartStore.add_item(fresh_session, build_item())

      CartStore.cleanup_expired(86_400)

      assert CartStore.get_cart(stale_session) == []
      assert length(CartStore.get_cart(fresh_session)) == 1
    end
  end

  describe "init/0" do
    test "is a compatibility no-op returning :ok" do
      assert CartStore.init() == :ok
    end
  end

  # -- Helpers --

  defp build_item(overrides \\ []) do
    defaults = %{
      variant_id: Keyword.get(overrides, :variant_id, Ecto.UUID.generate()),
      product_title: Keyword.get(overrides, :product_title, "Test Product"),
      variant_info: Keyword.get(overrides, :variant_info, "Default"),
      unit_price: Keyword.get(overrides, :unit_price, 5000),
      quantity: Keyword.get(overrides, :quantity, 1),
      sku: Keyword.get(overrides, :sku, "TST-001")
    }

    defaults
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
