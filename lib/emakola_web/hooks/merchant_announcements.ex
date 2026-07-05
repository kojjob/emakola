defmodule EmakolaWeb.Hooks.MerchantAnnouncements do
  @moduledoc """
  LiveView on_mount hook (merchant `:app` session) that assigns the active,
  non-dismissed platform announcements for the current store's banner and
  handles the `dismiss_announcement` event across all merchant LiveViews.

  Mounted after AssignDefaults (which sets current_merchant + current_store).
  Reads/writes use authorize?: false — merchant_id comes from the server-side
  session, never from request params.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias Emakola.Notifications
  alias Emakola.Stores.Store

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:announcements, load_announcements(socket))
      |> attach_hook(:merchant_announcements, :handle_event, &handle_dismiss/3)

    {:cont, socket}
  end

  defp handle_dismiss("dismiss_announcement", %{"id" => id}, socket) do
    merchant = socket.assigns[:current_merchant]

    if merchant do
      Notifications.dismiss_announcement(
        %{announcement_id: id, merchant_id: merchant.id},
        authorize?: false
      )
    end

    remaining = Enum.reject(socket.assigns.announcements, &(&1.id == id))
    {:halt, assign(socket, :announcements, remaining)}
  end

  defp handle_dismiss(_event, _params, socket), do: {:cont, socket}

  defp load_announcements(socket) do
    merchant = socket.assigns[:current_merchant]
    store = socket.assigns[:current_store]

    if merchant && store do
      store_live = Store.live?(store)

      with {:ok, active} <-
             Notifications.list_active_announcements(store_live, DateTime.utc_now(),
               authorize?: false
             ),
           {:ok, dismissed} <-
             Notifications.list_dismissed_announcement_ids(merchant.id, authorize?: false) do
        # dismissed are AnnouncementDismissal records — key by announcement_id,
        # NOT the dismissal row's own id.
        dismissed_ids = MapSet.new(dismissed, & &1.announcement_id)

        active
        |> Enum.filter(&(:banner in &1.channels))
        |> Enum.reject(&MapSet.member?(dismissed_ids, &1.id))
      else
        _ -> []
      end
    else
      []
    end
  end
end
