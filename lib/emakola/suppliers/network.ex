defmodule Emakola.Suppliers.Network do
  @moduledoc """
  Authorized service boundary for Makola Earn supply connections.

  A merchant may request from one of their stores, the other store must accept
  or reject, and either party may suspend or terminate an established link.
  """

  require Ash.Query

  alias Emakola.RateLimit
  alias Emakola.Suppliers
  alias Emakola.Suppliers.SupplyConnection

  @invite_burst_limit 3
  @invite_burst_window_ms 60_000
  @invite_day_limit 10
  @invite_day_window_ms 86_400_000

  def request(actor, attrs) do
    wholesaler_id = attrs[:wholesaler_store_id]
    reseller_id = attrs[:reseller_store_id]
    requester_id = attrs[:requested_by_store_id]

    with :ok <- ensure_distinct(wholesaler_id, reseller_id),
         :ok <- ensure_participant(requester_id, wholesaler_id, reseller_id),
         :ok <- ensure_access(actor, requester_id),
         :ok <- ensure_connection_absent(wholesaler_id, reseller_id),
         :ok <- ensure_invite_quota(requester_id),
         {:ok, connection} <- Suppliers.request_supply_connection(attrs, authorize?: false) do
      {:ok, notify(connection, "requested")}
    end
  end

  def list_for_store(actor, store_id) do
    with :ok <- ensure_access(actor, store_id) do
      Suppliers.list_supply_connections_for_store(store_id, authorize?: false)
    end
  end

  def approve(actor, connection) do
    case counterparty_update(actor, connection, :approve, %{}) do
      {:ok, updated} -> {:ok, notify(updated, "approved")}
      error -> error
    end
  end

  def reject(actor, connection, reason) do
    case counterparty_update(actor, connection, :reject, %{status_reason: reason}) do
      {:ok, updated} -> {:ok, notify(updated, "rejected")}
      error -> error
    end
  end

  def suspend(actor, connection, reason),
    do: participant_update(actor, connection, :suspend, %{status_reason: reason})

  def reactivate(actor, connection),
    do: participant_update(actor, connection, :reactivate, %{})

  def terminate(actor, connection, reason),
    do: participant_update(actor, connection, :terminate, %{status_reason: reason})

  def get(actor, connection_id) do
    with {:ok, connection} <- Ash.get(SupplyConnection, connection_id, authorize?: false),
         :ok <- ensure_access_to_either(actor, connection) do
      {:ok, connection}
    end
  end

  defp counterparty_update(actor, connection, action, attrs) do
    counterparty_id =
      if connection.requested_by_store_id == connection.wholesaler_store_id,
        do: connection.reseller_store_id,
        else: connection.wholesaler_store_id

    with :ok <- ensure_access(actor, counterparty_id) do
      update(connection, action, attrs)
    end
  end

  defp participant_update(actor, connection, action, attrs) do
    with :ok <- ensure_access_to_either(actor, connection) do
      update(connection, action, attrs)
    end
  end

  defp update(connection, action, attrs) do
    case connection
         |> Ash.Changeset.for_update(action, attrs)
         |> Ash.update(authorize?: false) do
      {:ok, updated} when action in [:suspend, :terminate] ->
        Emakola.Suppliers.ListingImporter.pause_connection_listings!(
          connection.wholesaler_store_id,
          connection.reseller_store_id
        )

        {:ok, updated}

      result ->
        result
    end
  end

  defp ensure_distinct(id, id), do: {:error, :stores_must_differ}
  defp ensure_distinct(nil, _), do: {:error, :invalid_store}
  defp ensure_distinct(_, nil), do: {:error, :invalid_store}
  defp ensure_distinct(_, _), do: :ok

  defp ensure_participant(id, wholesaler_id, reseller_id)
       when id in [wholesaler_id, reseller_id],
       do: :ok

  defp ensure_participant(_, _, _), do: {:error, :requester_must_be_participant}

  defp ensure_access_to_either(actor, connection) do
    case ensure_access(actor, connection.wholesaler_store_id) do
      :ok -> :ok
      _ -> ensure_access(actor, connection.reseller_store_id)
    end
  end

  defp ensure_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    case Emakola.Accounts.StoreMembership
         |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_access(_, _), do: {:error, :forbidden}

  defp ensure_invite_quota(store_id) do
    with {:allow, _} <-
           RateLimit.check_rate(
             "supply_invite:burst:#{store_id}",
             @invite_burst_limit,
             @invite_burst_window_ms
           ),
         {:allow, _} <-
           RateLimit.check_rate(
             "supply_invite:day:#{store_id}",
             @invite_day_limit,
             @invite_day_window_ms
           ) do
      :ok
    else
      {:deny, _} -> {:error, :invite_rate_limited}
    end
  end

  defp ensure_connection_absent(wholesaler_id, reseller_id) do
    case SupplyConnection
         |> Ash.Query.filter(
           wholesaler_store_id == ^wholesaler_id and reseller_store_id == ^reseller_id
         )
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, []} -> :ok
      {:ok, [_existing]} -> {:error, :connection_exists}
      {:error, reason} -> {:error, reason}
    end
  end

  defp notify(connection, event) do
    %{connection_id: connection.id, event: event}
    |> Emakola.Notifications.Workers.ConnectionNotificationWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("[Network] notification enqueue failed: #{inspect(reason)}")
        :ok
    end

    connection
  end
end
