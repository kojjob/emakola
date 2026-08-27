defmodule Emakola.Notifications.Workers.ProductModerationNotificationWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications.Workers.ProductModerationNotificationWorker, as: Worker

  setup :verify_on_exit!

  describe "enqueue/2" do
    test "inserts a job with string args" do
      product = Factory.create_product!(Factory.create_store!())
      assert {:ok, _} = Worker.enqueue(product.id, :product_taken_down)

      assert_enqueued(
        worker: Worker,
        args: %{"product_id" => product.id, "event" => "product_taken_down"}
      )
    end
  end

  describe "perform/1" do
    test "notifies the merchant (SMS) when the store has a phone" do
      store =
        Factory.create_store!(%{
          contact_phone: "+233201234567",
          contact_email: "shop@example.com"
        })

      product = Factory.create_product!(store, %{title: "Fake Bag"})

      expect(Emakola.SMSProviderMock, :send_sms, fn to, message, opts ->
        assert to == "+233201234567"
        assert message =~ "removed"
        assert message =~ "Fake Bag"
        assert opts[:store_id] == store.id
        {:ok, %{}}
      end)

      assert :ok =
               perform_job(Worker, %{"product_id" => product.id, "event" => "product_taken_down"})
    end

    test "a retried job does not ring the bell twice" do
      {merchant, store} =
        Factory.create_merchant_with_store!(%{contact_phone: "+233201234567"})

      product = Factory.create_product!(store, %{title: "Fake Bag"})

      expect(Emakola.SMSProviderMock, :send_sms, 2, fn _, _, _ -> {:error, :provider_down} end)

      args = %{"product_id" => product.id, "event" => "product_taken_down"}
      assert {:error, _} = perform_job(Worker, args, attempt: 1)
      assert {:error, _} = perform_job(Worker, args, attempt: 2)

      assert [_only_one] = Emakola.Notifications.list_for(merchant)
    end

    test "skips SMS gracefully when the store has no phone" do
      store = Factory.create_store!(%{contact_email: "shop@example.com"})
      product = Factory.create_product!(store)

      assert :ok =
               perform_job(Worker, %{"product_id" => product.id, "event" => "product_reinstated"})
    end

    test "returns an error for a missing product" do
      assert {:error, :product_not_found} =
               perform_job(Worker, %{
                 "product_id" => Ash.UUID.generate(),
                 "event" => "product_taken_down"
               })
    end
  end
end
