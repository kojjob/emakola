defmodule Emakola.Suppliers.Workers.GroupBuyExpiryWorker do
  @moduledoc """
  Cancels expired under-threshold group buys and executes each paid commitment
  refund exactly once. The sweep also revisits cancelled/refunded campaigns
  whose commitments are stuck in :paid, :refunding, or :refund_failed so no
  refund is ever terminal — a failed gateway call is retried by Oban first
  (error return) and by the next sweep after attempts are exhausted.
  """

  use Oban.Worker, queue: :payments, max_attempts: 3, unique: [period: 300, fields: [:args]]

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    case Emakola.Suppliers.GroupBuys.expire_and_refund(campaign_id) do
      {:ok, %{results: results}} ->
        if Enum.any?(results, &match?({:error, _, _}, &1)),
          do: {:error, :refund_failed},
          else: :ok

      {:error, :campaign_not_due} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    Emakola.Suppliers.GroupBuyCampaign
    |> Ash.Query.filter(
      (status == :open and deadline <= ^now and committed_quantity < threshold_quantity) or
        (status in [:cancelled, :refunded] and
           exists(commitments, status in [:paid, :refunding, :refund_failed]))
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
