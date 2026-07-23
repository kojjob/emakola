defmodule Emakola.Notifications.Workers.ConnectionNotificationWorker do
  @moduledoc """
  Notifies the counterparty of a supply-connection lifecycle event on all
  channels, best-effort per channel. `Network.request` is bidirectional
  (either the reseller or the wholesaler can initiate), so routing follows
  `requested_by_store_id` rather than a fixed store role:

    * "requested" → the NON-requesting store's owners (someone wants in)
    * "approved" / "rejected" → the REQUESTING store's owners (the decision)

  Copy is direction-aware: a reseller-initiated request reads "wants to
  stock your products" (`:wants_to_stock`); a wholesaler-initiated one reads
  "wants to supply you products" (`:wants_to_supply`). Approved/rejected
  copy is the same either way.

  Enqueued by Emakola.Suppliers.Network after the domain write succeeds.
  Unique per (connection_id, event); missing data logs and returns :ok.
  """
  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, keys: [:connection_id, :event]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.DeviceToken
  alias Emakola.Notifications.Templates

  @events ~w(requested approved rejected)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"connection_id" => id, "event" => event}})
      when event in @events do
    case load_connection(id) do
      nil ->
        Logger.warning("[ConnectionNotificationWorker] connection #{id} not found; skipping")
        :ok

      connection ->
        deliver(connection, event)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[ConnectionNotificationWorker] unknown args: #{inspect(args)}")
    :ok
  end

  defp deliver(connection, event) do
    {target_store_id, counterparty_name, direction} = routing(connection, event)
    event_atom = String.to_existing_atom(event)
    recipients = owner_merchants(target_store_id)

    if recipients == [] do
      Logger.warning(
        "[ConnectionNotificationWorker] no owner recipients for store #{target_store_id}"
      )
    end

    Enum.each(recipients, fn merchant ->
      attempt(
        fn -> send_sms(merchant, event_atom, counterparty_name, direction, target_store_id) end,
        "sms"
      )

      attempt(
        fn ->
          send_whatsapp(merchant, event_atom, counterparty_name, direction, target_store_id)
        end,
        "whatsapp"
      )
    end)

    attempt(
      fn -> send_push(target_store_id, event_atom, counterparty_name, direction, connection) end,
      "push"
    )

    :ok
  end

  # Routing follows requested_by_store_id, not a fixed store role — the
  # requester may be either side of the connection.
  defp routing(connection, "requested") do
    if requester_is_wholesaler?(connection) do
      {connection.reseller_store_id, connection.wholesaler_store.name, :wants_to_supply}
    else
      {connection.wholesaler_store_id, connection.reseller_store.name, :wants_to_stock}
    end
  end

  defp routing(connection, _decision) do
    if requester_is_wholesaler?(connection) do
      {connection.wholesaler_store_id, connection.reseller_store.name, :wants_to_supply}
    else
      {connection.reseller_store_id, connection.wholesaler_store.name, :wants_to_stock}
    end
  end

  defp requester_is_wholesaler?(connection),
    do: connection.requested_by_store_id == connection.wholesaler_store_id

  defp attempt(fun, channel) do
    fun.()
  rescue
    exception ->
      Logger.error(
        "[ConnectionNotificationWorker] #{channel} delivery failed: #{Exception.message(exception)}"
      )
  end

  defp send_sms(%{phone: phone}, event, counterparty, direction, store_id)
       when is_binary(phone) do
    sms_provider().send_sms(phone, Templates.connection_sms(event, counterparty, direction),
      store_id: store_id
    )
  end

  defp send_sms(_merchant, _event, _counterparty, _direction, _store_id), do: :ok

  defp send_whatsapp(%{phone: phone}, event, counterparty, direction, store_id)
       when is_binary(phone) do
    whatsapp_provider().send_message(
      phone,
      Templates.whatsapp_template_for(:supply_connection),
      Templates.connection_whatsapp_params(event, counterparty, direction),
      store_id: store_id
    )
  end

  defp send_whatsapp(_merchant, _event, _counterparty, _direction, _store_id), do: :ok

  # Mirrors PushNotificationWorker's provider invocation + device-token
  # resolution exactly: same for_store query, same token iteration, same
  # unregistered-token pruning and error handling.
  defp send_push(store_id, event, counterparty, direction, connection) do
    store_id
    |> device_tokens_for_store()
    |> Enum.each(&deliver_push(&1, event, counterparty, direction, connection))
  end

  defp device_tokens_for_store(store_id) do
    DeviceToken
    |> Ash.Query.for_read(:for_store)
    |> Ash.read!(authorize?: false, tenant: store_id)
  end

  defp deliver_push(device_token, event, counterparty, direction, connection) do
    notification =
      event
      |> Templates.connection_push(counterparty, direction)
      |> Map.put(:data, %{"connection_id" => connection.id, "event" => to_string(event)})

    case push_provider().send_push(device_token.token, notification) do
      {:ok, _} ->
        :ok

      {:error, :unregistered} ->
        Logger.info("[ConnectionNotificationWorker] pruning unregistered device token",
          connection_id: connection.id,
          store_id: device_token.store_id
        )

        prune(device_token)

      {:error, reason} ->
        Logger.error("[ConnectionNotificationWorker] push failed: #{inspect(reason)}",
          connection_id: connection.id,
          store_id: device_token.store_id
        )

        :ok
    end
  end

  # A concurrent job or the device re-registering may have deleted the row
  # already — that's success, not a failure worth crashing the fan-out for.
  defp prune(device_token) do
    case Ash.destroy(device_token, authorize?: false, tenant: device_token.store_id) do
      :ok ->
        :ok

      {:error, reason} ->
        if stale_or_not_found?(reason) do
          :ok
        else
          Logger.error("[ConnectionNotificationWorker] prune failed: #{inspect(reason)}",
            store_id: device_token.store_id
          )

          :ok
        end
    end
  end

  defp stale_or_not_found?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.StaleRecord{} -> true
      %Ash.Error.Query.NotFound{} -> true
      _ -> false
    end)
  end

  defp stale_or_not_found?(_reason), do: false

  defp load_connection(id) do
    Emakola.Suppliers.SupplyConnection
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:wholesaler_store, :reseller_store])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, connection} -> connection
      _ -> nil
    end
  end

  defp owner_merchants(store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(store_id == ^store_id and role == :owner)
    |> Ash.Query.load(:merchant)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.merchant)
  end

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end

  defp whatsapp_provider do
    Application.get_env(
      :emakola,
      :whatsapp_provider,
      Emakola.Notifications.Providers.LogWhatsApp
    )
  end

  defp push_provider do
    Application.get_env(:emakola, :push_provider, Emakola.Notifications.Providers.LogPush)
  end
end
