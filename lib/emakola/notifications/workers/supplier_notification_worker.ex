defmodule Emakola.Notifications.Workers.SupplierNotificationWorker do
  @moduledoc """
  Oban worker that notifies a dropship supplier about a fulfillment they
  are responsible for.

  Loads the fulfillment (with supplier, line_items, and order), picks the
  best contact channel (WhatsApp preferred, then SMS), sends the supplier
  the items to ship and the customer ship-to address, and transitions the
  fulfillment from `:pending` to `:notified`.

  This worker is idempotent — re-running for an already-notified fulfillment
  simply re-sends the message (acceptable for SMS/WhatsApp) without attempting
  an illegal status transition. Merchant-owned groups (`supplier_id` nil) are
  skipped: there is no external supplier to notify.

  ## Channels fall through; the rate limiter does not

  Channels are tried in order — WhatsApp first because it is free, then SMS.
  A failure on one moves to the next, EXCEPT `{:error, :rate_limited}`, which
  halts: that is the store's own 200/hour limiter firing, and falling through
  would convert a free WhatsApp into a paid SMS during exactly the runaway the
  limiter exists to stop.

  Contact details are checked for blankness, not truthiness. `whatsapp_number`
  has no constraints and the admin form is free text, so an empty string is
  truthy — it would route to WhatsApp, 400 at Meta, and never reach SMS.

  ## Why a final attempt returns `:ok`

  Returning `{:error, _}` forever is right for a timeout, and Oban retries with
  backoff. But at `max_attempts` the job discards and nothing on the fulfilment
  changes, which is the production failure verbatim: three 401s, dead letter,
  silence. So the failure is written on EVERY attempt — the merchant sees it
  within seconds rather than after the last backoff — and the final attempt
  returns `:ok` so the terminal state rests on the row the merchant looks at
  instead of in `oban_jobs`, where nobody will.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"fulfillment_id" => fulfillment_id}} = job) do
    last_attempt? = job.attempt >= job.max_attempts

    with {:ok, fulfillment} <- load_fulfillment(fulfillment_id) do
      cond do
        fulfillment.status == :cancelled ->
          Logger.info(
            "[SupplierNotificationWorker] Fulfillment #{fulfillment_id} was cancelled, skipping notification"
          )

          :ok

        is_nil(fulfillment.supplier_id) ->
          Logger.info(
            "[SupplierNotificationWorker] Fulfillment #{fulfillment_id} is a merchant group, nothing to send"
          )

          :ok

        true ->
          fulfillment |> notify_supplier() |> settle(fulfillment, last_attempt?)
      end
    else
      {:error, reason} ->
        Logger.error(
          "[SupplierNotificationWorker] Failed to process fulfillment #{fulfillment_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_fulfillment(fulfillment_id) do
    Emakola.Orders.Fulfillment
    |> Ash.Query.filter(id == ^fulfillment_id)
    |> Ash.Query.load([:supplier, :line_items, :order])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :fulfillment_not_found}
      {:ok, fulfillment} -> {:ok, fulfillment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp notify_supplier(fulfillment) do
    case channels(fulfillment.supplier) do
      [] ->
        Logger.info(
          "[SupplierNotificationWorker] Supplier #{fulfillment.supplier.id} has no contact info, manual fallback needed"
        )

        {:error, :no_contact}

      channels ->
        Enum.reduce_while(channels, {:error, :no_contact}, fn {channel, to}, _last ->
          case send_on(channel, to, fulfillment) do
            {:ok, _result} ->
              {:halt, {:ok, channel}}

            # The store's own limiter, not the provider's. Stop spending.
            {:error, :rate_limited} ->
              {:halt, {:error, :rate_limited}}

            {:error, reason} ->
              {:cont, {:error, {channel, reason}}}
          end
        end)
    end
  end

  # WhatsApp first because it is free. Blank-checked, not truthy-checked.
  defp channels(supplier) do
    [{:whatsapp, supplier.whatsapp_number}, {:sms, supplier.contact_phone}]
    |> Enum.reject(fn {_channel, value} -> blank?(value) end)
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: true

  defp send_on(:whatsapp, to, fulfillment) do
    whatsapp_provider().send_message(
      to,
      Templates.supplier_fulfillment_whatsapp_template(),
      Templates.supplier_fulfillment_whatsapp_params(
        fulfillment.order,
        fulfillment.supplier,
        fulfillment.line_items
      ),
      store_id: fulfillment.store_id
    )
  end

  defp send_on(:sms, to, fulfillment) do
    sms_provider().send_sms(
      to,
      Templates.supplier_fulfillment_sms(
        fulfillment.order,
        fulfillment.supplier,
        fulfillment.line_items,
        Emakola.Suppliers.SupplierAction.action_url(fulfillment)
      ),
      store_id: fulfillment.store_id
    )
  end

  defp settle({:ok, channel}, fulfillment, _last_attempt?) do
    maybe_mark_notified(fulfillment, channel)
  end

  # A supplier with no phone number is a PERMANENT condition, not a transient
  # one — no amount of retrying will add a number. Burning three Oban attempts
  # on it is pure noise, so record the label and stop.
  defp settle({:error, :no_contact}, fulfillment, _last_attempt?) do
    record_failure(fulfillment, :no_contact)
    :ok
  end

  defp settle({:error, reason}, fulfillment, last_attempt?) do
    record_failure(fulfillment, reason)

    # The channel is carried for the label but unwrapped here: Oban's error
    # surface stays the provider's own reason, as it always was.
    if last_attempt?, do: :ok, else: {:error, unwrap(reason)}
  end

  defp unwrap({_channel, reason}), do: reason
  defp unwrap(reason), do: reason

  # A label, never the provider body — that body can carry phone numbers and
  # Meta account ids. Capped well under the column's 64 characters.
  defp record_failure(fulfillment, reason) do
    fulfillment
    |> Ash.Changeset.for_update(:record_send_failure, %{last_send_error: label(reason)})
    |> Ash.update(authorize?: false)
    |> case do
      {:ok, _updated} ->
        :ok

      {:error, error} ->
        Logger.error(
          "[SupplierNotificationWorker] could not record send failure for #{fulfillment.id}: #{inspect(error)}"
        )

        :ok
    end
  end

  defp label(:no_contact), do: "no_contact"
  defp label(:rate_limited), do: "rate_limited"
  defp label({channel, reason}), do: String.slice("#{channel}:#{reason_label(reason)}", 0, 64)
  defp label(reason), do: String.slice(reason_label(reason), 0, 64)

  defp reason_label(%{status: status}), do: "http_#{status}"
  defp reason_label(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_label(reason), do: Emakola.Privacy.error_type(reason)

  # Transition pending -> notified after a successful send. A re-send of an
  # already-notified fulfillment must NOT attempt the transition again.
  defp maybe_mark_notified(%{status: :pending} = fulfillment, channel) do
    fulfillment
    |> Ash.Changeset.for_update(:mark_notified, %{notified_via: channel})
    |> Ash.update(authorize?: false)
    |> case do
      {:ok, _updated} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[SupplierNotificationWorker] Failed to mark fulfillment #{fulfillment.id} notified: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp maybe_mark_notified(_fulfillment, _channel), do: :ok

  defp sms_provider do
    Application.get_env(
      :emakola,
      :sms_provider,
      Emakola.Notifications.Providers.LogSMS
    )
  end

  defp whatsapp_provider do
    Application.get_env(
      :emakola,
      :whatsapp_provider,
      Emakola.Notifications.Providers.LogWhatsApp
    )
  end
end
