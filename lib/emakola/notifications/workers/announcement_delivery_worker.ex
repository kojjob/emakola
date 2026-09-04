defmodule Emakola.Notifications.Workers.AnnouncementDeliveryWorker do
  @moduledoc """
  Delivers one announcement to one store over its selected external channels
  (email / SMS / WhatsApp), skipping a channel the store hasn't filled in.

  Mirrors `StoreStatusNotificationWorker`: per-store retry isolation, no
  double-sends. A permanently-unknown WhatsApp template is treated as a SKIPPED
  channel (logged, :ok) so the job never wedges; a transient channel error fails
  the job so Oban retries.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Logger

  alias Emakola.Notifications

  @spec enqueue(binary(), binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(announcement_id, store_id)
      when is_binary(announcement_id) and is_binary(store_id) do
    %{"announcement_id" => announcement_id, "store_id" => store_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"announcement_id" => ann_id, "store_id" => store_id}}) do
    with {:ok, ann} <- Notifications.get_announcement(ann_id, authorize?: false),
         {:ok, store} <- load_store(store_id) do
      results = Enum.map(ann.channels, &send_channel(&1, ann, store))

      if Enum.any?(results, &match?({:error, _}, &1)) do
        Logger.error(
          "[AnnouncementDeliveryWorker] delivery failed for store #{store_id}: #{inspect(results)}"
        )

        {:error, :announcement_delivery_failed}
      else
        :ok
      end
    else
      {:error, _} -> {:error, :delivery_target_not_found}
    end
  end

  defp load_store(store_id) do
    case Emakola.Stores.get_store(store_id, authorize?: false) do
      {:ok, store} -> {:ok, store}
      _ -> {:error, :store_not_found}
    end
  end

  defp send_channel(:email, ann, store), do: maybe_send_email(ann, store)
  defp send_channel(:sms, ann, store), do: maybe_send_sms(ann, store)
  defp send_channel(:whatsapp, ann, store), do: maybe_send_whatsapp(ann, store)
  # :banner has no external send.
  defp send_channel(_other, _ann, _store), do: :ok

  defp maybe_send_sms(ann, %{contact_phone: phone} = store)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, ann.body, store_id: store.id)
  end

  defp maybe_send_sms(_ann, _store), do: :ok

  defp maybe_send_email(ann, %{contact_email: email} = store)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject(ann.title)
    |> Swoosh.Email.html_body(
      Emakola.Notifications.Emails.MarketingEmail.update(email_assigns(ann))
    )
    |> Swoosh.Email.text_body(ann.body)
    |> Emakola.Mailer.deliver()
  end

  defp maybe_send_email(_ann, _store), do: :ok

  # The announcement rides the "update" marketing template: title as the lead,
  # body as the story, severity as the eyebrow, one action back into the shop.
  defp email_assigns(ann) do
    %{
      update_type: severity_label(ann.severity),
      month: ann.publish_at && Calendar.strftime(ann.publish_at, "%B %Y"),
      headline: ann.title,
      body: ann.body,
      action: %{label: "Open my shop", url: EmakolaWeb.Endpoint.url() <> "/admin"}
    }
  end

  defp severity_label(:critical), do: "Urgent"
  defp severity_label(:warning), do: "Important"
  defp severity_label(_info), do: "Update"

  defp maybe_send_whatsapp(ann, %{whatsapp_number: number} = store)
       when is_binary(number) and number != "" do
    case whatsapp_provider().send_message(number, "announcement", %{title: ann.title},
           store_id: store.id
         ) do
      {:ok, _} ->
        :ok

      {:error, {:unknown_template, _}} ->
        Logger.info(
          "[AnnouncementDeliveryWorker] whatsapp 'announcement' template not live; skipping store #{store.id}"
        )

        :ok

      {:error, _} = err ->
        err
    end
  end

  defp maybe_send_whatsapp(_ann, _store), do: :ok

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)

  defp whatsapp_provider,
    do:
      Application.get_env(
        :emakola,
        :whatsapp_provider,
        Emakola.Notifications.Providers.LogWhatsApp
      )
end
