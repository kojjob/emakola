defmodule Emakola.Marketing.CampaignSendWorker do
  @moduledoc """
  Fans a campaign out to the store's reachable customers, one SMS each.

  **Claim, then send.** Each recipient row is written `:pending` *before* the
  provider call and only marked `:sent` after it returns. That ordering is the
  whole safety property: Oban retries a job whose process dies mid-run, and a
  row written after a successful send would leave the unique index guarding
  nothing — the duplicate SMS has already been paid for.

  A rejected number is recorded on its own row and the send continues. One bad
  number must not cost the merchant the rest of the campaign.

  There is no delivery or read reporting here, because neither channel gives
  us any without provider webhooks. `sent` means "the gateway accepted it".
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Logger

  alias Emakola.Marketing.{Campaign, CampaignRecipient, Campaigns}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    case Ash.get(Campaign, campaign_id, authorize?: false) do
      {:ok, campaign} -> send_guarding_status(campaign)
      # A deleted campaign is not a failure to retry.
      {:error, _} -> :ok
    end
  end

  # Mark the row :failed, then re-raise so Oban still records the attempt and
  # retries. Without this a discarded job left the campaign :sending forever:
  # the send handler only proceeds from :draft or :failed, so the Send button
  # never came back and the merchant could not retry from the page at all.
  #
  # With max_attempts: 3 the status flips :failed and back to :sending on each
  # retry, settling on :failed only once the attempts are spent. That flicker
  # is the honest reading of the state — the send is genuinely being retried.
  defp send_guarding_status(campaign) do
    send_campaign(campaign)
  rescue
    exception ->
      mark_failed(campaign)
      reraise(exception, __STACKTRACE__)
  end

  defp mark_failed(campaign) do
    campaign
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update(authorize?: false)
  rescue
    # Never let the bookkeeping write mask the real failure below it.
    exception ->
      Logger.warning(
        "campaign mark_failed raised campaign=#{campaign.id} " <>
          "reason=#{inspect(exception.__struct__)}"
      )
  end

  defp send_campaign(%Campaign{status: :sent}), do: :ok

  defp send_campaign(%Campaign{} = campaign) do
    {:ok, customers} = Campaigns.reachable_customers(campaign.store_id, campaign.audience)

    {:ok, campaign} =
      campaign
      |> Ash.Changeset.for_update(:mark_sending, %{audience_size: length(customers)})
      |> Ash.update(authorize?: false)

    Enum.each(customers, &deliver(campaign, &1))

    {sent, failed} = tally(campaign.id)

    campaign
    |> Ash.Changeset.for_update(:record_result, %{sent_count: sent, failed_count: failed})
    |> Ash.update(authorize?: false)

    :ok
  end

  defp deliver(campaign, customer) do
    case claim(campaign, customer) do
      # Already attempted on an earlier run — never send again.
      {:ok, %CampaignRecipient{status: status} = recipient} when status == :pending ->
        dispatch(campaign, customer, recipient)

      {:ok, _already_attempted} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "campaign recipient claim failed campaign=#{campaign.id} " <>
            "customer=#{customer.id} reason=#{inspect(reason)}"
        )
    end
  end

  defp claim(campaign, customer) do
    CampaignRecipient
    |> Ash.Changeset.for_create(:claim, %{
      campaign_id: campaign.id,
      customer_id: customer.id,
      phone: customer.phone
    })
    |> Ash.create(authorize?: false)
  end

  defp dispatch(campaign, customer, recipient) do
    case sms_provider().send_sms(customer.phone, campaign.body, store_id: campaign.store_id) do
      {:ok, _} ->
        recipient
        |> Ash.Changeset.for_update(:mark_sent, %{})
        |> Ash.update(authorize?: false)

      {:error, reason} ->
        recipient
        |> Ash.Changeset.for_update(:mark_failed, %{error: inspect(reason)})
        |> Ash.update(authorize?: false)
    end
  end

  defp tally(campaign_id) do
    {:ok, rows} =
      CampaignRecipient
      |> Ash.Query.for_read(:for_campaign, %{campaign_id: campaign_id})
      |> Ash.read(authorize?: false)

    Enum.reduce(rows, {0, 0}, fn
      %{status: :sent}, {sent, failed} -> {sent + 1, failed}
      %{status: :failed}, {sent, failed} -> {sent, failed + 1}
      _pending, acc -> acc
    end)
  end

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Channels.SMS)
  end
end
