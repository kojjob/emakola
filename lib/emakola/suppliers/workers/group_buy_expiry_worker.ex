defmodule Emakola.Suppliers.Workers.GroupBuyExpiryWorker do
  @moduledoc "Cancels expired under-threshold group buys and executes each paid commitment refund once."

  use Oban.Worker, queue: :payments, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    case Emakola.Suppliers.GroupBuys.expire_and_refund(campaign_id) do
      {:ok, _summary} -> :ok
      {:error, :campaign_not_due} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    Emakola.Suppliers.GroupBuyCampaign
    |> Ash.Query.filter(
      status == :open and deadline <= ^now and committed_quantity < threshold_quantity
    )
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn campaign ->
      %{campaign_id: campaign.id}
      |> new()
      |> Oban.insert!()
    end)

    :ok
  end
end
