defmodule Emakola.Notifications.Workers.VerificationStatusNotificationWorker do
  @moduledoc """
  Oban worker that notifies a merchant when the platform reviews their store's
  KYC submission (approved / rejected).

  Sends an SMS to the store's `contact_phone` and a plain-text email to its
  `contact_email`, skipping whichever channel isn't filled in. The rejection
  reason isn't included here — the merchant sees it (and resubmits) on their
  `/admin/verification` page; this is just the heads-up.

  Mirrors `StoreStatusNotificationWorker`: idempotent, with a `unique` window
  that absorbs retry storms and a double-clicked review action.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  @events [:verification_approved, :verification_rejected]

  @doc """
  Enqueues a verification-decision notification. Never raises.
  """
  @spec enqueue(binary(), atom()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(store_id, event) when is_binary(store_id) and event in @events do
    %{"store_id" => store_id, "event" => Atom.to_string(event)}
    |> new()
    |> Oban.insert()
  rescue
    exception ->
      Logger.error(
        "[VerificationStatusNotificationWorker] enqueue raised: #{Exception.message(exception)}"
      )

      {:error, {:enqueue_raised, Exception.message(exception)}}
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_id" => store_id, "event" => event_string}}) do
    event = Emakola.SafeAtom.to_atom_in(event_string, @events, :verification_rejected)

    case load_store(store_id) do
      {:ok, store} ->
        Emakola.Notifications.notify_store(store.id, :verification_result, %{
          title: verification_bell_title(event),
          action_url: "/admin/verification"
        })

        results = [maybe_send_sms(store, event), maybe_send_email(store, event)]

        if Enum.any?(results, &match?({:error, _}, &1)) do
          Logger.error(
            "[VerificationStatusNotificationWorker] delivery failed for store #{store_id}: #{inspect(results)}"
          )

          {:error, :notification_delivery_failed}
        else
          :ok
        end

      {:error, reason} ->
        Logger.error(
          "[VerificationStatusNotificationWorker] store #{store_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

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

  defp verification_bell_title(:verification_approved), do: "Your shop is verified"
  defp verification_bell_title(_rejected), do: "Verification needs another look"

  defp maybe_send_sms(%{contact_phone: phone} = store, event)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, message(store, event), store_id: store.id)
  end

  defp maybe_send_sms(store, _event) do
    Logger.info("[VerificationStatusNotificationWorker] no contact_phone for store #{store.id}")
    :ok
  end

  defp maybe_send_email(%{contact_email: email} = store, event)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject(subject(event))
    |> Swoosh.Email.text_body(message(store, event))
    |> Emakola.Mailer.deliver()
  end

  defp maybe_send_email(_store, _event), do: :ok

  defp subject(:verification_approved), do: "Your Makola store is verified"
  defp subject(:verification_rejected), do: "Action needed on your Makola verification"

  defp message(store, :verification_approved),
    do:
      "#{store.name}: your store has been verified. The verified badge now shows on your storefront."

  defp message(store, :verification_rejected),
    do:
      "#{store.name}: your store verification needs attention. Sign in to see what to fix and resubmit."

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
