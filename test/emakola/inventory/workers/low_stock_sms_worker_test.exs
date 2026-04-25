defmodule Emakola.Inventory.Workers.LowStockSmsWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Factory
  alias Emakola.Inventory.Workers.LowStockSmsWorker

  setup :verify_on_exit!

  setup do
    {merchant, store} = Factory.create_merchant_with_store!()
    product = Factory.create_product!(store, status: :active)

    variant =
      Factory.create_variant!(product, store, price: 5000, stock_quantity: 3, sku: "TEST-SKU")

    # Set low_stock_alerted to true (as checkout would have done)
    variant =
      variant
      |> Ash.Changeset.for_update(:set_low_stock_alerted, %{})
      |> Ash.update!(authorize?: false)

    %{store: store, merchant: merchant, variant: variant, product: product}
  end

  describe "perform/1" do
    test "sends SMS when store has contact_phone and variant is alerted", %{
      store: store,
      variant: variant
    } do
      store =
        store
        |> Ash.Changeset.for_update(:update_settings, %{contact_phone: "+233244123456"})
        |> Ash.update!(authorize?: false)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233244123456"
        assert message =~ "Low stock alert"
        assert message =~ "TEST-SKU"
        assert message =~ store.name
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok ==
               perform_job(LowStockSmsWorker, %{
                 "variant_id" => variant.id,
                 "store_id" => store.id
               })
    end

    test "skips sending when variant low_stock_alerted is false", %{
      store: store,
      variant: variant
    } do
      variant
      |> Ash.Changeset.for_update(:clear_low_stock_alerted, %{})
      |> Ash.update!(authorize?: false)

      # No SMS expectation — should not be called
      assert :ok ==
               perform_job(LowStockSmsWorker, %{
                 "variant_id" => variant.id,
                 "store_id" => store.id
               })
    end

    test "handles missing variant gracefully" do
      assert :ok ==
               perform_job(LowStockSmsWorker, %{
                 "variant_id" => Ash.UUID.generate(),
                 "store_id" => Ash.UUID.generate()
               })
    end
  end
end
