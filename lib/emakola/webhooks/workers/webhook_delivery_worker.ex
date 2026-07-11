defmodule Emakola.Webhooks.Workers.WebhookDeliveryWorker do
  @moduledoc "Delivers outbound webhooks with HMAC-SHA256 signing."
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    %{
      "webhook_id" => webhook_id,
      "event_type" => event_type,
      "payload" => payload
    } = args

    # Look up url + secret from the resource at perform time so we
    # don't persist secrets in `oban_jobs.args`.
    case load_webhook(webhook_id) do
      nil ->
        {:cancel, "webhook #{webhook_id} not found"}

      %{active: false} ->
        {:cancel, "webhook #{webhook_id} disabled"}

      webhook ->
        deliver(webhook, event_type, payload, attempt)
    end
  end

  defp load_webhook(id) do
    Emakola.Webhooks.OutboundWebhook
    |> Ash.get(id, authorize?: false)
    |> case do
      {:ok, webhook} -> webhook
      _ -> nil
    end
  end

  defp deliver(%{id: webhook_id, url: url, secret: secret}, event_type, payload, attempt) do
    body = Jason.encode!(payload)
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    signature = compute_hmac(secret, timestamp, body)

    headers = [
      {"content-type", "application/json"},
      {"x-webhook-signature", signature},
      {"x-webhook-timestamp", timestamp},
      {"x-webhook-event", event_type},
      {"user-agent", "Emakola-Webhook/1.0"}
    ]

    # Create delivery record
    {:ok, delivery} =
      Emakola.Webhooks.WebhookDelivery
      |> Ash.Changeset.for_create(:create, %{
        event_type: event_type,
        payload: payload,
        webhook_id: webhook_id
      })
      |> Ash.create()

    case Req.post(url, body: body, headers: headers, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        delivery
        |> Ash.Changeset.for_update(:mark_delivered, %{
          response_status: status,
          attempts: attempt
        })
        |> Ash.update()

        :ok

      {:ok, %{status: status, body: resp_body}} ->
        error_body = if is_binary(resp_body), do: resp_body, else: inspect(resp_body)

        delivery
        |> Ash.Changeset.for_update(:mark_failed, %{
          response_status: status,
          response_body: String.slice(error_body, 0..999),
          error: "HTTP #{status}",
          attempts: attempt
        })
        |> Ash.update()

        {:error, "HTTP #{status}"}

      {:error, reason} ->
        delivery
        |> Ash.Changeset.for_update(:mark_failed, %{
          error: inspect(reason),
          attempts: attempt
        })
        |> Ash.update()

        {:error, reason}
    end
  end

  @doc "Compute HMAC-SHA256 signature for webhook verification."
  def compute_hmac(secret, timestamp, body) do
    payload = "#{timestamp}.#{body}"

    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end
end
