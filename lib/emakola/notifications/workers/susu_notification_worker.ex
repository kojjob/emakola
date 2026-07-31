defmodule Emakola.Notifications.Workers.SusuNotificationWorker do
  @moduledoc """
  Oban worker for susu plan lifecycle notifications that occur BEFORE the
  plan's order exists (TC-3 Task 8) — see
  `Emakola.Notifications.Dispatcher.dispatch_susu/2`'s moduledoc for why
  this is a separate, plan-keyed worker rather than a fork inside
  `OrderNotificationWorker`.

  Covers activation, chunk progress, nudges, deadline warnings, and
  non-completion end-of-life (refund/expiry). SMS-only — no approved
  WhatsApp template exists for these events yet, mirroring
  `OrderNotificationWorker`'s posture for the TC-2 protection events.

  Loads the plan (and store, and — for buyer-facing events — the plan's
  customer, when one has been resolved) fresh at send time, so a nudge or
  deadline-warning message always reflects the plan's real remaining
  balance and real days-to-deadline, never a value stashed at enqueue
  time.

  Idempotent — re-running for the same plan/event simply re-sends the
  SMS (acceptable for SMS, same discipline as `OrderNotificationWorker`).
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Payment

  @buyer_events ~w(
    susu_activated susu_chunk_received susu_nudge susu_deadline_warning susu_refunded
  )a
  @merchant_events ~w(susu_merchant_activated susu_merchant_expired)a

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"susu_plan_id" => plan_id, "event" => event_string}}) do
    event =
      Emakola.SafeAtom.to_atom_in(
        event_string,
        [
          :susu_activated,
          :susu_chunk_received,
          :susu_nudge,
          :susu_deadline_warning,
          :susu_refunded,
          :susu_merchant_activated,
          :susu_merchant_expired
        ],
        :susu_activated
      )

    with {:ok, plan} <- load_plan(plan_id),
         {:ok, store} <- load_store(plan.store_id) do
      if event in @buyer_events, do: send_buyer_sms(plan, store, event)
      if event in @merchant_events, do: send_merchant_sms(plan, store, event)
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "[SusuNotificationWorker] Failed to process notification for plan #{plan_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_plan(plan_id) do
    SusuPlan
    |> Ash.Query.filter(id == ^plan_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :plan_not_found}
      {:ok, plan} -> {:ok, plan}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_store(store_id) do
    Emakola.Stores.Store
    |> Ash.Query.filter(id == ^store_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :store_not_found}
      {:ok, store} -> {:ok, store}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_customer(nil), do: nil

  defp load_customer(customer_id) do
    case Emakola.Customers.Customer
         |> Ash.Query.filter(id == ^customer_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, customer} -> customer
      _ -> nil
    end
  end

  defp send_buyer_sms(plan, store, event) do
    customer = load_customer(plan.customer_id)

    if customer && customer.phone do
      message = buyer_sms_template(plan, store, event)
      sms_provider().send_sms(customer.phone, message, store_id: plan.store_id)
    else
      Logger.info(
        "[SusuNotificationWorker] No customer phone for plan #{plan.id}, skipping buyer notification"
      )
    end
  end

  defp buyer_sms_template(plan, store, :susu_activated),
    do: Templates.susu_activated_sms(plan, store)

  defp buyer_sms_template(plan, store, :susu_chunk_received),
    do: Templates.susu_chunk_received_sms(plan, store)

  defp buyer_sms_template(plan, store, :susu_nudge),
    do: Templates.susu_nudge_sms(plan, store)

  defp buyer_sms_template(plan, store, :susu_deadline_warning),
    do: Templates.susu_deadline_warning_sms(plan, store)

  defp buyer_sms_template(plan, store, :susu_refunded),
    do: Templates.susu_refunded_sms(plan, store, refunded_amount(plan))

  # The plan's real collected payments — NOT `plan.contributed_amount`,
  # which undercounts (stays 0) on the insufficient-stock path. `:success`
  # (refund initiated, webhook not landed yet — the common case, since
  # this SMS composes right after `SusuLifecycle`'s `converge/1` call) OR
  # `:refunded` (this job ran late enough that the `refund.processed`
  # webhook already confirmed it) — either way, the money was collected
  # and is/was being refunded. See `Templates.susu_refunded_sms/3`'s doc.
  defp refunded_amount(%SusuPlan{id: plan_id}) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan_id and status in [:success, :refunded])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  defp send_merchant_sms(plan, store, event) do
    if store.contact_phone do
      message = merchant_sms_template(plan, store, event)
      sms_provider().send_sms(store.contact_phone, message, store_id: plan.store_id)
    else
      Logger.info(
        "[SusuNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp merchant_sms_template(plan, store, :susu_merchant_activated),
    do: Templates.susu_merchant_activated_sms(plan, store)

  defp merchant_sms_template(plan, store, :susu_merchant_expired),
    do: Templates.susu_merchant_expired_sms(plan, store)

  defp sms_provider do
    Application.get_env(
      :emakola,
      :sms_provider,
      Emakola.Notifications.Providers.LogSMS
    )
  end
end
