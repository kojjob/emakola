defmodule Emakola.Notifications.Workers.StoreStatusNotificationWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications.Workers.StoreStatusNotificationWorker, as: Worker

  setup :verify_on_exit!

  describe "enqueue/2" do
    test "inserts a job with string args" do
      store = Factory.create_store!()
      assert {:ok, _} = Worker.enqueue(store.id, :store_suspended)

      assert_enqueued(
        worker: Worker,
        args: %{"store_id" => store.id, "event" => "store_suspended"}
      )
    end
  end

  describe "perform/1" do
    test "sends an SMS when the store has a contact phone" do
      store =
        Factory.create_store!(%{
          contact_phone: "+233201234567",
          contact_email: "shop@example.com"
        })

      expect(Emakola.SMSProviderMock, :send_sms, fn to, message, opts ->
        assert to == "+233201234567"
        assert message =~ "suspended"
        assert opts[:store_id] == store.id
        {:ok, %{}}
      end)

      assert :ok = perform_job(Worker, %{"store_id" => store.id, "event" => "store_suspended"})
    end

    test "skips SMS gracefully when the store has no contact phone" do
      store = Factory.create_store!(%{contact_email: "shop@example.com"})
      # No SMS expectation: the provider must not be called.
      assert :ok = perform_job(Worker, %{"store_id" => store.id, "event" => "store_reactivated"})
    end

    test "fails the job when an attempted channel errors (so Oban retries)" do
      store = Factory.create_store!(%{contact_phone: "+233201234567"})

      expect(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts ->
        {:error, :provider_down}
      end)

      assert {:error, _} =
               perform_job(Worker, %{"store_id" => store.id, "event" => "store_suspended"})
    end

    test "returns an error for a missing store" do
      assert {:error, :store_not_found} =
               perform_job(Worker, %{
                 "store_id" => Ash.UUID.generate(),
                 "event" => "store_suspended"
               })
    end
  end
end
