defmodule Emakola.Webhooks do
  @moduledoc "Webhooks domain — outbound webhook registration and per-delivery attempt tracking."
  use Ash.Domain

  resources do
    resource Emakola.Webhooks.OutboundWebhook do
      define(:create_webhook, action: :create)
      define(:list_webhooks, action: :read)
      define(:get_webhook, action: :read, get_by: [:id])
    end

    resource Emakola.Webhooks.WebhookDelivery do
      define(:create_delivery, action: :create)
      define(:list_deliveries, action: :read)
    end
  end

  @doc "Dispatch a webhook event to all matching org webhooks."
  def dispatch(org_id, event_type, payload) do
    require Ash.Query

    Emakola.Webhooks.OutboundWebhook
    |> Ash.Query.filter(organisation_id: org_id, active: true)
    |> Ash.read!()
    |> Enum.filter(fn wh -> event_type in wh.events end)
    |> Enum.each(fn webhook ->
      %{
        webhook_id: webhook.id,
        event_type: event_type,
        payload: payload,
        url: webhook.url,
        secret: webhook.secret
      }
      |> Emakola.Webhooks.Workers.WebhookDeliveryWorker.new()
      |> Oban.insert()
    end)
  end
end
