defmodule Emakola.Notifications.Workers.PayoutNotificationWorkerTest do
  @moduledoc """
  Notifies a merchant when their payout is paid — SMS to contact_phone + email to
  contact_email, skipping a missing channel, failing only on an attempted error.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox
  import Swoosh.TestAssertions

  alias Emakola.Factory
  alias Emakola.Notifications.Workers.PayoutNotificationWorker, as: Worker
  alias Emakola.Payments

  setup :verify_on_exit!

  defp paid_payout!(store, amount \\ 50_000) do
    Payments.create_payout!(
      %{
        store_id: store.id,
        amount: amount,
        transfer_reference: "po_#{System.unique_integer([:positive])}"
      },
      authorize?: false
    )
  end

  test "enqueue/1 inserts a job" do
    assert {:ok, _} = Worker.enqueue("payout-1")
    assert_enqueued(worker: Worker, args: %{"payout_id" => "payout-1"})
  end

  test "sends an SMS with the amount to the store's contact_phone" do
    store = Factory.create_store!(%{name: "Kente Kingdom", contact_phone: "+233244123456"})
    payout = paid_payout!(store, 50_000)

    expect(Emakola.SMSProviderMock, :send_sms, fn to, msg, opts ->
      assert to == "+233244123456"
      assert msg =~ "Kente Kingdom"
      assert msg =~ "500"
      assert opts[:store_id] == store.id
      {:ok, %{}}
    end)

    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})
  end

  test "sends an email to the store's contact_email" do
    store = Factory.create_store!(%{name: "Email Co", contact_email: "shop@example.com"})
    payout = paid_payout!(store)

    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})

    assert_email_sent(fn email ->
      assert {_, "shop@example.com"} = hd(email.to)
      assert email.text_body =~ "Email Co"
    end)
  end

  test "skips SMS gracefully when the store has no contact_phone" do
    store = Factory.create_store!(%{name: "No Phone Co"})
    payout = paid_payout!(store)

    # No SMS expectation — the provider must not be called.
    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})
  end

  test "fails the job when an attempted SMS errors so Oban retries" do
    store = Factory.create_store!(%{contact_phone: "+233244123456"})
    payout = paid_payout!(store)

    expect(Emakola.SMSProviderMock, :send_sms, fn _, _, _ -> {:error, :provider_down} end)

    assert {:error, _} = perform_job(Worker, %{"payout_id" => payout.id})
  end

  test "no-ops when the payout no longer exists" do
    assert :ok = perform_job(Worker, %{"payout_id" => Ecto.UUID.generate()})
  end
end
