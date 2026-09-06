defmodule Emakola.Orders.AbandonedCheckoutsTest do
  @moduledoc """
  A buyer who typed their phone and left is a sale waiting for one message.
  Nothing here sends anything; it remembers who left and hands the merchant a
  WhatsApp link.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.AbandonedCheckouts

  setup do
    {:ok, store: create_store!(%{name: "Ama's Shop", slug: "amas-shop"})}
  end

  @cart %{
    phone: "0241234567",
    name: "Kojo",
    items: [%{"title" => "Kente stole", "quantity" => 2, "unit_price" => 5_000}],
    cart_total: 10_000
  }

  defp seen_hours_ago!(checkout, hours) do
    at = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    Emakola.Repo.query!("update abandoned_checkouts set last_seen_at = $1 where id = $2", [
      at,
      Ecto.UUID.dump!(checkout.id)
    ])
  end

  test "touching twice keeps one row per cart, with the latest contents", %{store: store} do
    {:ok, first} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    {:ok, second} = AbandonedCheckouts.touch(store.id, "cart-1", %{@cart | cart_total: 15_000})

    assert first.id == second.id
    assert second.cart_total == 15_000
    assert second.phone == "+233241234567"
  end

  test "left behind means older than two hours, newer than seven days, not recovered", %{
    store: store
  } do
    {:ok, fresh} = AbandonedCheckouts.touch(store.id, "cart-fresh", @cart)
    {:ok, stale} = AbandonedCheckouts.touch(store.id, "cart-stale", @cart)
    {:ok, old} = AbandonedCheckouts.touch(store.id, "cart-old", @cart)
    {:ok, bought} = AbandonedCheckouts.touch(store.id, "cart-bought", @cart)
    seen_hours_ago!(stale, 3)
    seen_hours_ago!(old, 24 * 8)
    seen_hours_ago!(bought, 3)

    order = create_order!(store, %{subtotal: 100, total: 100})
    :ok = AbandonedCheckouts.recover(store.id, "cart-bought", order.id)

    assert Enum.map(AbandonedCheckouts.left_behind(store.id), & &1.id) == [stale.id]
    assert AbandonedCheckouts.count_left_behind(store.id) == 1
    _ = {fresh, old}
  end

  test "a pay-link order from the same phone recovers the cart", %{store: store} do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_hours_ago!(checkout, 3)
    order = create_order!(store, %{subtotal: 100, total: 100})

    :ok = AbandonedCheckouts.recover_by_phone(store.id, "+233241234567", order.id)

    assert AbandonedCheckouts.left_behind(store.id) == []
  end

  test "the WhatsApp link carries the message", %{store: store} do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)

    url = AbandonedCheckouts.whatsapp_url(checkout, store)

    assert String.starts_with?(url, "https://wa.me/233241234567?text=")
    assert URI.decode_www_form(url) =~ "Kente stole"
    assert URI.decode_www_form(url) =~ "Ama's Shop"
  end
end
