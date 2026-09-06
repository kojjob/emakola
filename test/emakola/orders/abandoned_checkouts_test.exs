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

  defp seen_hours_ago!(checkout, hours), do: seen_seconds_ago!(checkout, hours * 3600)

  defp seen_seconds_ago!(checkout, seconds) do
    at = DateTime.add(DateTime.utc_now(), -seconds, :second)

    Emakola.Repo.query!("update abandoned_checkouts set last_seen_at = $1 where id = $2", [
      at,
      Ecto.UUID.dump!(checkout.id)
    ])
  end

  defp all_rows, do: Ash.read!(Emakola.Orders.AbandonedCheckout, authorize?: false)

  test "touching twice keeps one row per cart, with the latest contents", %{store: store} do
    {:ok, first} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    {:ok, second} = AbandonedCheckouts.touch(store.id, "cart-1", %{@cart | cart_total: 15_000})

    assert first.id == second.id
    assert second.cart_total == 15_000
    assert second.phone == "+233241234567"
  end

  test "touching again refreshes last_seen_at instead of keeping the stale time", %{
    store: store
  } do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_hours_ago!(checkout, 5)

    {:ok, _touched_again} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)

    assert AbandonedCheckouts.left_behind(store.id) == []
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

  test "the prune worker forgets carts older than thirty days", %{store: store} do
    {:ok, old} = AbandonedCheckouts.touch(store.id, "cart-old", @cart)
    {:ok, recent} = AbandonedCheckouts.touch(store.id, "cart-recent", @cart)
    seen_hours_ago!(old, 24 * 31)

    assert :ok = Emakola.Orders.Workers.AbandonedCheckoutPruneWorker.perform(%Oban.Job{})

    assert Enum.map(all_rows(), & &1.id) == [recent.id]
  end

  test "the prune worker on an empty table returns :ok" do
    assert :ok = Emakola.Orders.Workers.AbandonedCheckoutPruneWorker.perform(%Oban.Job{})
  end

  test "touch refuses a phone that fails PhoneAuth.valid?/1 and writes nothing", %{store: store} do
    assert {:error, :invalid_phone} =
             AbandonedCheckouts.touch(store.id, "cart-bad-phone", %{@cart | phone: "abc"})

    refute Enum.any?(all_rows(), &(&1.cart_session_id == "cart-bad-phone"))
  end

  test "a name with control characters (a newline) is stored clean", %{store: store} do
    {:ok, checkout} =
      AbandonedCheckouts.touch(store.id, "cart-1", %{@cart | name: "Kojo\nDankwa"})

    refute checkout.name =~ "\n"
    assert checkout.name == "KojoDankwa"
  end

  test "a cart with more lines than the cap stores only the first fifty", %{store: store} do
    lines =
      Enum.map(1..120, fn n ->
        %{"title" => "Item #{n}", "quantity" => 1, "unit_price" => 100}
      end)

    {:ok, checkout} =
      AbandonedCheckouts.touch(store.id, "cart-huge", %{@cart | items: lines})

    assert length(checkout.items) == 50
    assert List.first(checkout.items)["title"] == "Item 1"
  end

  test "recovering a row deleted between the read and the write does not raise", %{
    store: store
  } do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_hours_ago!(checkout, 3)

    Emakola.Repo.query!("delete from abandoned_checkouts where id = $1", [
      Ecto.UUID.dump!(checkout.id)
    ])

    order = create_order!(store, %{subtotal: 100, total: 100})
    assert :ok = AbandonedCheckouts.recover(store.id, "cart-1", order.id)
  end

  test "a row older than seven days is not recovered", %{store: store} do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_hours_ago!(checkout, 24 * 8)
    order = create_order!(store, %{subtotal: 100, total: 100})

    :ok = AbandonedCheckouts.recover(store.id, "cart-1", order.id)

    row = Enum.find(all_rows(), &(&1.id == checkout.id))
    assert row.recovered_at == nil
  end

  test "a checkout last seen exactly two hours ago is listed", %{store: store} do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_hours_ago!(checkout, 2)

    assert Enum.map(AbandonedCheckouts.left_behind(store.id), & &1.id) == [checkout.id]
  end

  test "a checkout last seen just past seven days is not listed", %{store: store} do
    {:ok, checkout} = AbandonedCheckouts.touch(store.id, "cart-1", @cart)
    seen_seconds_ago!(checkout, 7 * 86_400 + 1)

    assert AbandonedCheckouts.left_behind(store.id) == []
  end
end
