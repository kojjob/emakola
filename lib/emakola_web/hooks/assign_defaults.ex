defmodule EmakolaWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.

  Merchant and platform application pages are private, so this hook also marks
  every LiveView in those authenticated sessions as `noindex, nofollow`.

  Authentication strategy:
  1. Try to resolve a platform-staff session from :platform_session_token
     (signed DB-backed session id — see `Emakola.Accounts.Sessions`)
  2. Otherwise resolve :user_token as a Merchant (ecommerce user) and load
     their first store via StoreMembership
  3. Assign current_user, current_session_id, current_merchant,
     current_store accordingly
  """
  require Logger

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, session, socket) do
    socket =
      assign(socket,
        active_nav: :dashboard,
        setup_banner_dismissed: false,
        impersonator: nil,
        robots: "noindex, nofollow"
      )

    case resolve_platform_session(socket, session["platform_session_token"]) do
      {:ok, socket} ->
        {:cont, attach_notification_hook(socket)}

      :error ->
        resolve_merchant_token(socket, session["user_token"], session)
    end
  end

  defp resolve_platform_session(socket, signed_token) do
    with {:ok, session_id} <- EmakolaWeb.AuthTokens.verify_platform_session(signed_token),
         {:ok, user, user_session} <- Emakola.Accounts.Sessions.verify_session_id(session_id) do
      if Phoenix.LiveView.connected?(socket) do
        Emakola.Accounts.Sessions.touch(user_session)
      end

      {notifs, unread} = load_notifications(socket, user)

      {:ok,
       assign(socket,
         current_user: user,
         current_session_id: user_session.id,
         current_merchant: nil,
         current_store: nil,
         onboarding_complete: true,
         notifications: notifs,
         unread_notification_count: unread,
         pending_order_count: 0
       )}
    else
      _ -> :error
    end
  end

  # The `:user_token` path also carries platform-staff impersonation: when the
  # session holds an active `:impersonation`, the resolved merchant is the
  # impersonated one and `impersonator` is the real staff user (for the banner).
  # An expired window bounces to the exit controller, which restores the staff
  # session. A normal merchant login has no `:impersonation` → impersonator nil.
  defp resolve_merchant_token(socket, signed_token, session) do
    case impersonation_state(session) do
      :expired ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/platform/impersonate/exit")}

      state ->
        impersonator =
          case state do
            {:active, staff} -> staff
            _ -> nil
          end

        case EmakolaWeb.AuthTokens.verify_subject_with_iat(signed_token) do
          {:error, _reason} ->
            {:cont, assign_unauthenticated(socket)}

          {:ok, subject, issued_at} ->
            {:cont,
             socket
             |> resolve_merchant(subject, impersonator, issued_at)
             |> attach_notification_hook()}
        end
    end
  end

  defp resolve_merchant(socket, token, impersonator, issued_at) do
    case AshAuthentication.subject_to_user(token, Emakola.Accounts.Merchant) do
      # A valid signature only proves we minted this token, not that it is
      # still current — a password reset moves the merchant's cutoff past it.
      {:ok, merchant} when not is_nil(merchant) ->
        if Emakola.Accounts.session_live?(merchant, issued_at) do
          resolve_live_merchant(socket, merchant, impersonator)
        else
          assign_unauthenticated(socket)
        end

      _ ->
        assign_unauthenticated(socket)
    end
  end

  defp resolve_live_merchant(socket, merchant, impersonator) do
    store = load_merchant_store(merchant.id)
    {notifs, unread} = load_notifications(socket, merchant)
    # Defer the 4 stat-count queries to the connected mount — the disconnected
    # dead render throws them away (CLAUDE.md: no DB work in the dead render).
    stats =
      if Phoenix.LiveView.connected?(socket),
        do: load_store_stats(store),
        else: load_store_stats(nil)

    assign(socket,
      current_merchant: merchant,
      current_store: store,
      current_user: nil,
      impersonator: impersonator,
      onboarding_complete: true,
      notifications: notifs,
      unread_notification_count: unread,
      product_count: stats.products,
      order_count: stats.orders,
      customer_count: stats.customers,
      pending_order_count: stats.pending_orders
    )
  end

  # `:none` (no/!impersonation), `:expired` (window elapsed → force exit), or
  # `{:active, staff_user}`. Only the impersonation start controller ever sets
  # `:impersonation`, so a real merchant login is always `:none`.
  defp impersonation_state(session) do
    case session["impersonation"] do
      %{"expires_at" => expires_at, "staff_user_id" => staff_id} ->
        if expired?(expires_at) do
          :expired
        else
          case Emakola.Accounts.get_user_by_id(staff_id, authorize?: false) do
            {:ok, staff} -> {:active, staff}
            _ -> :expired
          end
        end

      _ ->
        :none
    end
  end

  defp expired?(expires_at) when is_integer(expires_at), do: System.os_time(:second) >= expires_at
  defp expired?(_), do: true

  defp assign_unauthenticated(socket) do
    assign(socket,
      current_merchant: nil,
      current_store: nil,
      current_user: nil,
      impersonator: nil,
      onboarding_complete: false,
      notifications: [],
      unread_notification_count: 0,
      pending_order_count: 0
    )
  end

  defp attach_notification_hook(socket) do
    socket
    |> Phoenix.LiveView.attach_hook(
      :notification_actions,
      :handle_event,
      &handle_notification_event/3
    )
    |> Phoenix.LiveView.attach_hook(
      :notification_arrivals,
      :handle_info,
      &handle_notification_info/2
    )
  end

  # The bell is in the layout, on every page, so arrivals cannot depend on any
  # one LiveView subscribing. `:cont` on a non-match is load-bearing — halting
  # would swallow each page's own messages.
  defp handle_notification_info({:new_notification, notification}, socket) do
    notifications = [notification | socket.assigns[:notifications] || []]

    {:cont,
     assign(socket,
       notifications: Enum.take(notifications, 20),
       unread_notification_count: (socket.assigns[:unread_notification_count] || 0) + 1
     )}
  end

  defp handle_notification_info(_message, socket), do: {:cont, socket}

  defp load_merchant_store(merchant_id) do
    case Emakola.Accounts.get_merchant_store_membership(merchant_id, authorize?: false) do
      {:ok, nil} -> nil
      {:ok, membership} -> Ash.load!(membership, :store, authorize?: false).store
      _ -> nil
    end
  end

  defp handle_notification_event("mark_all_notifications_read", _params, socket) do
    # One statement for the whole bell. The previous version looped over the
    # 20 loaded rows, which both cost a query each and quietly left a 21st
    # unread notification behind.
    case notification_recipient(socket) do
      nil ->
        {:halt, socket}

      recipient ->
        Emakola.Notifications.mark_all_read_for(recipient)
        now = DateTime.utc_now()

        read =
          Enum.map(socket.assigns[:notifications] || [], fn notification ->
            %{notification | read_at: notification.read_at || now}
          end)

        {:halt, assign(socket, notifications: read, unread_notification_count: 0)}
    end
  end

  defp handle_notification_event(_event, _params, socket), do: {:cont, socket}

  # Whichever actor this session belongs to. Both are never set at once —
  # the merchant path nils current_user and vice versa.
  defp notification_recipient(socket) do
    socket.assigns[:current_merchant] || socket.assigns[:current_user]
  end

  defp load_store_stats(nil), do: %{products: 0, orders: 0, customers: 0, pending_orders: 0}

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

    {:ok, pending_order_count} =
      Emakola.Orders.Order
      |> Ash.Query.for_read(:list_by_status, %{store_id: store.id, status: :pending})
      |> Ash.count(authorize?: false)

    %{
      products: product_count,
      orders: order_count,
      customers: customer_count,
      pending_orders: pending_order_count
    }
  rescue
    exception ->
      Logger.error("[assign_defaults] load_store_stats raised: #{Exception.message(exception)}")
      %{products: 0, orders: 0, customers: 0, pending_orders: 0}
  end

  # Deferred to the connected mount like the other counts — the dead render
  # throws the result away. Subscribing here rather than in each LiveView
  # because the bell lives in the layout and is on every page.
  #
  # The count is its own query rather than `Enum.count` over the loaded rows:
  # the list is capped at 20, so counting it would cap the badge at 20 too.
  defp load_notifications(socket, recipient) do
    if Phoenix.LiveView.connected?(socket) && recipient do
      Emakola.Notifications.subscribe(recipient)

      {Emakola.Notifications.list_for(recipient),
       Emakola.Notifications.unread_count_for(recipient)}
    else
      {[], 0}
    end
  rescue
    exception ->
      Logger.error("[assign_defaults] load_notifications raised: #{Exception.message(exception)}")
      {[], 0}
  end
end
