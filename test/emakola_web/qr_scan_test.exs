defmodule EmakolaWeb.QRScanTest do
  @moduledoc """
  Reading a scanned code — the mirror of `EmakolaWeb.QR`, which writes them.

  The rule this module exists to enforce: a scan is never a destination. What
  comes back off a camera is a string a stranger may have printed and taped to
  a parcel, so it is treated as a *claim about an identifier*, resolved inside
  the acting merchant's own store, and nothing else. It is never followed as a
  URL and never used to reach another store's data.
  """
  use Emakola.DataCase, async: true

  alias EmakolaWeb.QR
  alias EmakolaWeb.QRScan

  setup do
    store = Emakola.Factory.create_store!()
    other_store = Emakola.Factory.create_store!()
    customer = Emakola.Factory.create_customer!(store)
    order = Emakola.Factory.create_order!(store, %{customer_id: customer.id, status: :processing})

    {:ok, store: store, other_store: other_store, order: order}
  end

  describe "resolving our own payload" do
    test "the exact string our own QR encodes resolves to that order", %{
      store: store,
      order: order
    } do
      # The round trip that matters: whatever EmakolaWeb.QR printed on the slip
      # is what the camera hands back, so these two must agree by construction.
      scanned = QR.order_tracking_url(store, order)

      assert {:ok, resolved} = QRScan.resolve_order(scanned, store.id)
      assert resolved.id == order.id
    end

    test "a bare order number resolves too", %{store: store, order: order} do
      assert {:ok, resolved} = QRScan.resolve_order(order.order_number, store.id)
      assert resolved.id == order.id
    end

    test "surrounding whitespace does not defeat a scan", %{store: store, order: order} do
      assert {:ok, _} = QRScan.resolve_order("  #{order.order_number}\n", store.id)
    end
  end

  describe "tenant isolation" do
    test "another store's order is not found, not forbidden", %{
      other_store: other_store,
      store: store,
      order: order
    } do
      # Scanned from the acting merchant = other_store. The order belongs to
      # `store`. :not_found rather than :forbidden so a merchant cannot use the
      # scanner to probe which order numbers exist elsewhere on the platform.
      scanned = QR.order_tracking_url(store, order)

      assert {:error, :not_found} = QRScan.resolve_order(scanned, other_store.id)
    end

    test "a payload naming another store's slug still resolves against the actor's store",
         %{store: store, order: order} do
      # The slug in the payload is decoration — the lookup is scoped by the
      # store_id the caller passes, which comes from the session, never the QR.
      scanned = "https://makola.io/s/some-other-shop/track/#{order.order_number}"

      assert {:ok, resolved} = QRScan.resolve_order(scanned, store.id)
      assert resolved.id == order.id
    end
  end

  describe "hostile and malformed input" do
    test "a foreign host cannot redirect the merchant anywhere", %{store: store, order: order} do
      # A sticker slapped on a parcel pointing at an attacker's domain. The host
      # is discarded entirely: only the identifier is read, and it is resolved
      # inside the merchant's own store. There is no code path that navigates
      # to a scanned host.
      scanned = "https://evil.example/s/kente/track/#{order.order_number}"

      assert {:ok, resolved} = QRScan.resolve_order(scanned, store.id)
      assert resolved.id == order.id
    end

    test "a javascript: payload is refused", %{store: store} do
      assert {:error, _} = QRScan.resolve_order("javascript:alert(1)", store.id)
    end

    test "an unrelated QR is simply not found", %{store: store} do
      assert {:error, _} = QRScan.resolve_order("WIFI:S:MyNetwork;T:WPA;P:hunter2;;", store.id)
    end

    test "an absurdly long payload is refused before it reaches the database", %{store: store} do
      assert {:error, :unrecognised} =
               QRScan.resolve_order(String.duplicate("A", 5_000), store.id)
    end

    test "empty and non-binary input are refused", %{store: store} do
      assert {:error, :unrecognised} = QRScan.resolve_order("", store.id)
      assert {:error, :unrecognised} = QRScan.resolve_order("   ", store.id)
      assert {:error, :unrecognised} = QRScan.resolve_order(nil, store.id)
    end

    test "a trailing slash or query string does not defeat a scan", %{
      store: store,
      order: order
    } do
      base = QR.order_tracking_url(store, order)

      assert {:ok, _} = QRScan.resolve_order(base <> "/", store.id)
      assert {:ok, _} = QRScan.resolve_order(base <> "?utm_source=whatsapp", store.id)
    end
  end
end
