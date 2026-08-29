defmodule Emakola.Notifications.EarningsNotificationTest do
  @moduledoc """
  Money-surfaces PR-2 Task 3: the `:earnings_accrued` notification —
  merchants learn money arrived without opening the admin.

  (a) settling a payment with wholesaler+dropshipper recipients enqueues one
      `EarningsNotificationWorker` job PER recipient (never for :platform).
  (c) the worker's template renders the net amount + source description, and
      the MoMo-nudge line exactly when `PayoutService.momo_destination?/1` is
      false — see `Emakola.Payments.PaystackWebhookHandlerTest`'s
      "idempotency" describe block for the webhook-replay case (b), and
      `Emakola.Notifications.DispatcherTest`'s "dispatch_earnings/2 does not
      raise" describe block for the no-raise contract (d).
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.EarningsNotificationWorker
  alias Emakola.Payments.Workers.PaystackWebhookHandler
  alias Emakola.Stores.StorePayoutAccount

  setup :verify_on_exit!

  defp split!(payment, store, attrs) do
    Emakola.Payments.create_payment_split!(
      Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs)),
      authorize?: false
    )
  end

  defp charge_success!(payment) do
    PaystackWebhookHandler.perform(%Oban.Job{
      args: %{"event" => "charge.success", "data" => %{"reference" => payment.gateway_reference}}
    })
  end

  defp give_momo_destination!(store) do
    StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244#{System.unique_integer([:positive])}",
        "account_name" => "Test Payout"
      }
    })
    |> Ash.create!(authorize?: false)
  end

  # ── (a) one job per recipient, none for :platform ──────────────────

  describe "settle_splits dispatch" do
    test "wholesaler + dropshipper recipients each enqueue one earnings job; :platform does not" do
      dropshipper = create_store!(name: "Dropshipper A")
      wholesaler_store = create_store!(name: "Wholesaler A")

      payment =
        create_payment!(dropshipper,
          amount: 13_000,
          split_mode: :dropship_split,
          gateway_reference: "PAY-earn-#{System.unique_integer([:positive])}"
        )

      split!(payment, dropshipper, %{
        role: :wholesaler,
        recipient_store_id: wholesaler_store.id,
        subaccount_code: "ACCT_w",
        amount: 1_600
      })

      split!(payment, dropshipper, %{role: :platform, amount: 840})

      split!(payment, dropshipper, %{
        role: :dropshipper,
        recipient_store_id: dropshipper.id,
        subaccount_code: "ACCT_d",
        amount: 10_560
      })

      assert :ok = charge_success!(payment)

      jobs = all_enqueued(worker: EarningsNotificationWorker)
      assert length(jobs) == 2

      recipient_ids = Enum.map(jobs, & &1.args["recipient_store_id"])
      assert wholesaler_store.id in recipient_ids
      assert dropshipper.id in recipient_ids

      assert Enum.all?(jobs, &(&1.args["payment_id"] == payment.id))
    end

    test "a normal own-stock sale (single :merchant split) enqueues exactly one earnings job" do
      store = create_store!(name: "Solo Merchant")

      payment =
        create_payment!(store,
          amount: 5_000,
          gateway_reference: "PAY-earn-solo-#{System.unique_integer([:positive])}"
        )

      split!(payment, store, %{role: :merchant, recipient_store_id: store.id, amount: 4_500})
      split!(payment, store, %{role: :platform, amount: 500})

      assert :ok = charge_success!(payment)

      assert [job] = all_enqueued(worker: EarningsNotificationWorker)
      assert job.args["payment_id"] == payment.id
      assert job.args["recipient_store_id"] == store.id
    end
  end

  # ── (c) template content via the worker ─────────────────────────────

  describe "perform/1 — buyer's own sale, no MoMo destination" do
    test "renders net amount, 'your sale', and the MoMo nudge line" do
      store = create_store!(name: "Nudge Store")

      store =
        store
        |> Ash.Changeset.for_update(:update_settings, %{contact_phone: "+233301234567"})
        |> Ash.update!(authorize?: false)

      payment = create_payment!(store, amount: 5_000)
      split!(payment, store, %{role: :merchant, recipient_store_id: store.id, amount: 4_500})

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == "+233301234567"
        assert message =~ "45.00"
        assert message =~ "your sale"
        assert message =~ "mobile money"
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok ==
               EarningsNotificationWorker.perform(%Oban.Job{
                 args: %{
                   "payment_id" => payment.id,
                   "recipient_store_id" => store.id,
                   "event" => "earnings_accrued"
                 }
               })
    end
  end

  describe "perform/1 — resale via another store, MoMo destination configured" do
    test "renders net amount, 'resale via <name>', and omits the MoMo nudge line" do
      dropshipper = create_store!(name: "Source Store")
      wholesaler_store = create_store!(name: "Wholesaler B")

      wholesaler_store =
        wholesaler_store
        |> Ash.Changeset.for_update(:update_settings, %{contact_phone: "+233201234567"})
        |> Ash.update!(authorize?: false)

      give_momo_destination!(wholesaler_store)

      payment = create_payment!(dropshipper, amount: 5_000, split_mode: :dropship_split)

      split!(payment, dropshipper, %{
        role: :wholesaler,
        recipient_store_id: wholesaler_store.id,
        amount: 1_600
      })

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == "+233201234567"
        assert message =~ "16.00"
        assert message =~ "resale via Source Store"
        refute message =~ "mobile money"
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok ==
               EarningsNotificationWorker.perform(%Oban.Job{
                 args: %{
                   "payment_id" => payment.id,
                   "recipient_store_id" => wholesaler_store.id,
                   "event" => "earnings_accrued"
                 }
               })
    end
  end

  describe "perform/1 — no contact_phone" do
    test "skips cleanly, no SMS sent" do
      store = create_store!(name: "No Phone Store")
      payment = create_payment!(store, amount: 5_000)
      split!(payment, store, %{role: :merchant, recipient_store_id: store.id, amount: 4_500})

      # No SMS expectation set — a call here would fail via Mox.
      assert :ok ==
               EarningsNotificationWorker.perform(%Oban.Job{
                 args: %{
                   "payment_id" => payment.id,
                   "recipient_store_id" => store.id,
                   "event" => "earnings_accrued"
                 }
               })
    end
  end
end
