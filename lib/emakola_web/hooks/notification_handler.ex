defmodule EmakolaWeb.Hooks.NotificationHandler do
  @moduledoc """
  LiveView on_mount hook that loads unread notifications, subscribes to
  PubSub for real-time updates, and handles notification-related events.

  Must be mounted after AssignDefaults (which sets current_user).
  """
  import Phoenix.Component
  import Phoenix.LiveView

  require Ash.Query
  require Logger

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if connected?(socket) && user do
      Phoenix.PubSub.subscribe(Emakola.PubSub, "user_notifications:#{user.id}")
    end

    notifications = load_unread_notifications(user)

    socket =
      socket
      |> assign(notifications: notifications, notification_count: length(notifications))
      |> attach_hook(:notification_handler, :handle_info, &handle_notification_info/2)
      |> attach_hook(:notification_events, :handle_event, &handle_notification_event/3)

    {:cont, socket}
  end

  defp handle_notification_info({:new_notification, notif}, socket) do
    notifications = [notif | socket.assigns.notifications]

    {:cont,
     assign(socket, notifications: notifications, notification_count: length(notifications))}
  end

  defp handle_notification_info(_msg, socket), do: {:cont, socket}

  defp handle_notification_event("mark_all_read", _params, socket) do
    for notif <- socket.assigns.notifications do
      notif |> Ash.Changeset.for_update(:mark_read) |> Ash.update()
    end

    {:halt, assign(socket, notifications: [], notification_count: 0)}
  end

  defp handle_notification_event("mark_notification_read", %{"id" => id}, socket) do
    notif = Enum.find(socket.assigns.notifications, &(&1.id == id))

    if notif do
      notif |> Ash.Changeset.for_update(:mark_read) |> Ash.update()
      notifications = Enum.reject(socket.assigns.notifications, &(&1.id == id))

      {:halt,
       assign(socket, notifications: notifications, notification_count: length(notifications))}
    else
      {:cont, socket}
    end
  end

  defp handle_notification_event("global_search", %{"q" => query}, socket) do
    query = String.trim(query) |> String.downcase()

    path =
      cond do
        query == "" ->
          nil

        String.contains?(query, "agent") ->
          "/agents"

        String.contains?(query, "bill") or String.contains?(query, "plan") ->
          "/billing"

        String.contains?(query, "team") or String.contains?(query, "member") ->
          "/team"

        String.contains?(query, "setting") ->
          "/settings"

        String.contains?(query, "work") ->
          "/workspaces"

        true ->
          "/activity"
      end

    if path do
      {:halt, push_navigate(socket, to: path)}
    else
      {:halt, socket}
    end
  end

  defp handle_notification_event(_event, _params, socket), do: {:cont, socket}

  defp load_unread_notifications(nil), do: []

  defp load_unread_notifications(user) do
    case Emakola.Notifications.Notification
         |> Ash.Query.filter(user_id == ^user.id and is_nil(read_at))
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(10)
         |> Ash.read(authorize?: false) do
      {:ok, notifs} ->
        notifs

      {:error, error} ->
        Logger.warning("Failed to load notifications: #{inspect(error)}")
        []
    end
  end
end
