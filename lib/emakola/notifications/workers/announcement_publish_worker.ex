defmodule Emakola.Notifications.Workers.AnnouncementPublishWorker do
  @moduledoc """
  Publishes a scheduled announcement at its `publish_at`: flips status to
  :published and fans out one `AnnouncementDeliveryWorker` per target store for
  the external channels. The in-app banner is query-driven and needs no job.

  Idempotent: a :canceled or already-:published announcement is a no-op.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Ash.Query

  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker

  @external_channels [:email, :sms, :whatsapp]

  @spec enqueue(binary(), DateTime.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(announcement_id, %DateTime{} = publish_at) when is_binary(announcement_id) do
    %{"announcement_id" => announcement_id}
    |> new(scheduled_at: publish_at)
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"announcement_id" => id}}) do
    case Notifications.get_announcement(id, authorize?: false) do
      {:ok, %{status: :scheduled} = ann} ->
        case Notifications.publish_announcement(ann, authorize?: false) do
          {:ok, published} ->
            enqueue_deliveries(published)
            :ok

          # Return a structured error (not a MatchError) so Oban retries cleanly.
          # The status==:scheduled guard above prevents a retry from re-publishing
          # / re-fanning-out once a prior attempt committed :published.
          {:error, reason} ->
            {:error, {:publish_failed, reason}}
        end

      {:ok, _other_status} ->
        :ok

      {:error, _} ->
        {:error, :announcement_not_found}
    end
  end

  defp enqueue_deliveries(%{channels: channels} = ann) do
    if Enum.any?(channels, &(&1 in @external_channels)) do
      Enum.each(target_store_ids(ann), &AnnouncementDeliveryWorker.enqueue(ann.id, &1))
    end

    :ok
  end

  defp target_store_ids(%{audience: :active}) do
    Emakola.Stores.Store
    |> Ash.Query.filter(active == true and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp target_store_ids(%{audience: :all}) do
    Emakola.Stores.Store
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end
end
