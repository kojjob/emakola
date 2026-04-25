defmodule Emakola.Orders.CheckoutLowStockAlertTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Factory
  alias Emakola.Orders.CheckoutService

  setup :verify_on_exit!

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)

    # Stub SMS and WhatsApp mocks so notification dispatch does not fail
    Emakola.SMSProviderMock
    |> stub(:send_sms, fn _to, _message, _opts ->
      {:ok, %{provider: :mock}}
    end)

    Emakola.WhatsAppProviderMock
    |> stub(:send_message, fn _to, _template, _params, _opts ->
      {:ok, %{provider: :mock}}
    end)

    %{store: store, customer: customer, product: product}
  end

  describe "checkout triggers low stock alert" do
    test "enqueues LowStockSmsWorker when stock drops below threshold", %{
      store: store,
      customer: customer,
      product: product
    } do
      variant = Factory.create_variant!(product, store, price: 1000, stock_quantity: 12)

      {:ok, _order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 5}],
          customer_id: customer.id
        )

      assert_enqueued(
        worker: Emakola.Inventory.Workers.LowStockSmsWorker,
        args: %{"variant_id" => variant.id, "store_id" => store.id}
      )

      updated =
        Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false, authorize?: false)

      assert updated.low_stock_alerted == true
    end

    test "does NOT enqueue when stock remains above threshold", %{
      store: store,
      customer: customer,
      product: product
    } do
      variant = Factory.create_variant!(product, store, price: 1000, stock_quantity: 20)

      {:ok, _order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 5}],
          customer_id: customer.id
        )

      refute_enqueued(worker: Emakola.Inventory.Workers.LowStockSmsWorker)
    end

    test "does NOT enqueue duplicate alert for already-alerted variant", %{
      store: store,
      customer: customer,
      product: product
    } do
      variant = Factory.create_variant!(product, store, price: 1000, stock_quantity: 8)

      variant
      |> Ash.Changeset.for_update(:set_low_stock_alerted, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}],
          customer_id: customer.id
        )

      refute_enqueued(worker: Emakola.Inventory.Workers.LowStockSmsWorker)
    end
  end

  describe "restock resets alert flag" do
    test "adjusting stock above threshold clears low_stock_alerted", %{
      store: store,
      product: product
    } do
      variant = Factory.create_variant!(product, store, price: 1000, stock_quantity: 3)

      variant =
        variant
        |> Ash.Changeset.for_update(:set_low_stock_alerted, %{})
        |> Ash.update!(authorize?: false)

      # Restock: add 20 units (total 23, above 10) — uses :restock action
      # which resets low_stock_alerted when new stock >= threshold
      variant
      |> Ash.Changeset.for_update(:restock, %{delta: 20})
      |> Ash.update!(authorize?: false)

      updated =
        Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false, authorize?: false)

      assert updated.low_stock_alerted == false
    end
  end
end
