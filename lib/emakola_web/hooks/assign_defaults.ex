defmodule EmakolaWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.

  Authentication strategy:
  1. Try to resolve session token as a Merchant (ecommerce user)
  2. If merchant found, load their first store via StoreMembership
  3. Fall back to User auth (legacy FounderPad) if not a merchant subject
  4. Assign current_merchant, current_store, current_user accordingly
  """
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, session, socket) do
    socket = assign(socket, active_nav: :dashboard, setup_banner_dismissed: false)

    case session["user_token"] do
      nil ->
        {:cont,
         assign(socket,
           current_merchant: nil,
           current_store: nil,
           current_user: nil,
           onboarding_complete: false,
           notifications: [],
           unread_notification_count: 0
         )}

      token ->
        socket =
          socket
          |> resolve_auth(token)
          |> Phoenix.LiveView.attach_hook(
            :notification_actions,
            :handle_event,
            &handle_notification_event/3
          )

        {:cont, socket}
    end
  end

  defp resolve_auth(socket, token) do
    cond do
      String.starts_with?(token, "merchant?") ->
        resolve_merchant(socket, token)

      String.starts_with?(token, "user?") ->
        resolve_user(socket, token)

      true ->
        # Unknown subject format — try merchant first, then user
        case try_merchant(token) do
          {:ok, merchant} ->
            store = load_merchant_store(merchant.id)
            {notifs, unread} = load_notifications(nil)
            stats = load_store_stats(store)

            assign(socket,
              current_merchant: merchant,
              current_store: store,
              current_user: nil,
              onboarding_complete: true,
              notifications: notifs,
              unread_notification_count: unread,
              product_count: stats.products,
              order_count: stats.orders,
              customer_count: stats.customers
            )

          _ ->
            resolve_user(socket, token)
        end
    end
  end

  defp resolve_merchant(socket, token) do
    case try_merchant(token) do
      {:ok, merchant} ->
        store = load_merchant_store(merchant.id)
        {notifs, unread} = load_notifications(nil)
        stats = load_store_stats(store)

        assign(socket,
          current_merchant: merchant,
          current_store: store,
          current_user: nil,
          onboarding_complete: true,
          notifications: notifs,
          unread_notification_count: unread,
          product_count: stats.products,
          order_count: stats.orders,
          customer_count: stats.customers
        )

      _ ->
        assign(socket,
          current_merchant: nil,
          current_store: nil,
          current_user: nil,
          onboarding_complete: false,
          notifications: [],
          unread_notification_count: 0
        )
    end
  end

  defp resolve_user(socket, token) do
    case AshAuthentication.subject_to_user(token, Emakola.Accounts.User) do
      {:ok, user} ->
        onboarding_complete = has_membership?(user.id)
        {notifs, unread} = load_notifications(user.id)

        assign(socket,
          current_user: user,
          current_merchant: nil,
          current_store: nil,
          onboarding_complete: onboarding_complete,
          notifications: notifs,
          unread_notification_count: unread
        )

      _ ->
        assign(socket,
          current_user: nil,
          current_merchant: nil,
          current_store: nil,
          onboarding_complete: false,
          notifications: [],
          unread_notification_count: 0
        )
    end
  end

  defp try_merchant(token) do
    AshAuthentication.subject_to_user(token, Emakola.Accounts.Merchant)
  end

  defp load_merchant_store(merchant_id) do
    case Emakola.Accounts.get_merchant_store_membership(merchant_id, authorize?: false) do
      {:ok, nil} -> nil
      {:ok, membership} -> Ash.load!(membership, :store, authorize?: false).store
      _ -> nil
    end
  end

  defp handle_notification_event("mark_all_notifications_read", _params, socket) do
    notifs = socket.assigns[:notifications] || []

    updated =
      Enum.map(notifs, fn notif ->
        if is_nil(notif.read_at) do
          case Emakola.Notifications.mark_as_read(notif, authorize?: false) do
            {:ok, updated} -> updated
            _ -> notif
          end
        else
          notif
        end
      end)

    {:halt,
     socket
     |> assign(notifications: updated, unread_notification_count: 0)}
  end

  defp handle_notification_event(_event, _params, socket), do: {:cont, socket}

  defp load_store_stats(nil), do: %{products: 0, orders: 0, customers: 0}

  defp load_store_stats(store) do
    {:ok, product_count} =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
      |> Ash.count(authorize?: false)

    {:ok, order_count} =
      Emakola.Orders.Order
      |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
      |> Ash.count(authorize?: false)

    {:ok, customer_count} =
      Emakola.Customers.Customer
      |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
      |> Ash.count(authorize?: false)

    %{products: product_count || 0, orders: order_count || 0, customers: customer_count || 0}
  rescue
    _ -> %{products: 0, orders: 0, customers: 0}
  end

  defp load_notifications(user_id) do
    case user_id do
      nil ->
        {[], 0}

      uid ->
        case Emakola.Notifications.list_notifications_by_user(uid, authorize?: false) do
          {:ok, notifs} ->
            unread = Enum.count(notifs, &is_nil(&1.read_at))
            {notifs, unread}

          _ ->
            {[], 0}
        end
    end
  rescue
    _ -> {[], 0}
  end

  defp has_membership?(user_id) do
    case Emakola.Accounts.list_memberships_by_user(user_id, authorize?: false) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
