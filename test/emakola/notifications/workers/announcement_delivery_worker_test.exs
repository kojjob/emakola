defmodule Emakola.Notifications.Workers.AnnouncementDeliveryWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker, as: Worker

  setup :verify_on_exit!

  defp announcement!(channels) do
    {:ok, ann} =
      Notifications.create_announcement(
        %{
          title: "Heads up",
          body: "Big news for your store.",
          channels: channels,
          audience: :all,
          publish_at: ~U[2026-06-20 00:00:00Z]
        },
        authorize?: false
      )

    ann
  end

  test "sends SMS to a store with a contact phone" do
    store = Factory.create_store!(%{contact_phone: "+233201234567"})
    ann = announcement!([:sms])

    expect(Emakola.SMSProviderMock, :send_sms, fn to, message, _opts ->
      assert to == "+233201234567"
      assert message =~ "Big news"
      {:ok, %{}}
    end)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "skips SMS when the store has no contact phone" do
    store = Factory.create_store!(%{contact_phone: nil, contact_email: nil})
    ann = announcement!([:sms])
    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "treats an unknown WhatsApp template as a skipped channel (no job failure)" do
    store = Factory.create_store!(%{whatsapp_number: "+233201234567"})
    ann = announcement!([:whatsapp])

    expect(Emakola.WhatsAppProviderMock, :send_message, fn _to, "announcement", _params, _opts ->
      {:error, {:unknown_template, "announcement"}}
    end)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "fails the job when an attempted channel errors transiently (so Oban retries)" do
    store = Factory.create_store!(%{contact_phone: "+233201234567"})
    ann = announcement!([:sms])

    expect(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts -> {:error, :provider_down} end)

    assert {:error, _} =
             perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end
end
