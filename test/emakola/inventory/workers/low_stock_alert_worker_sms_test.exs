defmodule Emakola.Inventory.Workers.LowStockAlertWorkerSmsTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Mox

  alias Emakola.Factory
  alias Emakola.Inventory.Workers.LowStockAlertWorker

  setup :verify_on_exit!

  setup do
    {merchant, store} = Factory.create_merchant_with_store!()

    store =
      store
      |> Ash.Changeset.for_update(:update_settings, %{contact_phone: "+233244123456"})
      |> Ash.update!()

    product = Factory.create_product!(store, status: :active)
    Factory.create_variant!(product, store, price: 5000, stock_quantity: 2, sku: "LOW-1")

    %{store: store, merchant: merchant}
  end

  describe "perform/1 sends SMS digest" do
    test "completes without error when low stock items exist", %{store: store} do
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233244123456"
        assert message =~ "running low"
        assert message =~ store.name
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(LowStockAlertWorker, %{})
    end

    test "does not crash when store has no contact_phone" do
      {_merchant, store2} = Factory.create_merchant_with_store!()
      product2 = Factory.create_product!(store2, status: :active)
      Factory.create_variant!(product2, store2, price: 5000, stock_quantity: 1)

      # SMS will be called for the first store (from setup) but not for store2
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _message, _opts ->
        {:ok, %{provider: :mock}}
      end)

      assert :ok == perform_job(LowStockAlertWorker, %{})
    end
  end
end
