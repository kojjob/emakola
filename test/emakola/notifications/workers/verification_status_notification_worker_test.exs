defmodule Emakola.Notifications.Workers.VerificationStatusNotificationWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications.Workers.VerificationStatusNotificationWorker, as: Worker

  setup :verify_on_exit!

  describe "enqueue/2" do
    test "inserts a job with string args" do
      store = Factory.create_store!()
      assert {:ok, _} = Worker.enqueue(store.id, :verification_approved)

      assert_enqueued(
        worker: Worker,
        args: %{"store_id" => store.id, "event" => "verification_approved"}
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
        assert message =~ "verified"
        assert opts[:store_id] == store.id
        {:ok, %{}}
      end)

      assert :ok =
               perform_job(Worker, %{"store_id" => store.id, "event" => "verification_approved"})
    end

    test "a retried job does not ring the bell twice" do
      {merchant, store} =
        Factory.create_merchant_with_store!(%{contact_phone: "+233201234567"})

      expect(Emakola.SMSProviderMock, :send_sms, 2, fn _, _, _ -> {:error, :provider_down} end)

      args = %{"store_id" => store.id, "event" => "verification_approved"}
      assert {:error, _} = perform_job(Worker, args, attempt: 1)
      assert {:error, _} = perform_job(Worker, args, attempt: 2)

      assert [_only_one] = Emakola.Notifications.list_for(merchant)
    end

    test "skips SMS gracefully when the store has no contact phone" do
      store = Factory.create_store!(%{contact_email: "shop@example.com"})

      assert :ok =
               perform_job(Worker, %{"store_id" => store.id, "event" => "verification_rejected"})
    end

    test "fails the job when an attempted channel errors (so Oban retries)" do
      store = Factory.create_store!(%{contact_phone: "+233201234567"})

      expect(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts ->
        {:error, :provider_down}
      end)

      assert {:error, _} =
               perform_job(Worker, %{"store_id" => store.id, "event" => "verification_approved"})
    end

    test "returns an error for a missing store" do
      assert {:error, :store_not_found} =
               perform_job(Worker, %{
                 "store_id" => Ash.UUID.generate(),
                 "event" => "verification_approved"
               })
    end
  end
end
