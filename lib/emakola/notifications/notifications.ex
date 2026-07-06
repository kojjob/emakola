defmodule Emakola.Notifications do
  @moduledoc "Notifications domain — SMS, WhatsApp, and email delivery with notification and email log resources."
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/v1")
  end

  resources do
    resource(Emakola.Notifications.DeviceToken)

    resource Emakola.Notifications.Notification do
      define(:create_notification, action: :create)
      define(:list_notifications, action: :read)
      define(:mark_as_read, action: :mark_read)
      define(:mark_all_read, action: :mark_all_read)
      define(:list_unread_notifications, action: :unread, args: [:user_id])
      define(:list_notifications_by_user, action: :list_by_user, args: [:user_id])
    end

    resource Emakola.Notifications.EmailLog do
      define(:create_email_log, action: :create)
      define(:list_email_logs, action: :read)
    end

    resource Emakola.Notifications.Announcement do
      define(:create_announcement, action: :create)
      define(:publish_announcement, action: :publish)
      define(:cancel_announcement, action: :cancel)
      define(:get_announcement, action: :read, get_by: [:id])
      define(:list_announcements_for_admin, action: :list_for_admin)
      define(:list_active_announcements, action: :active_for_store, args: [:store_live, :as_of])
    end

    resource Emakola.Notifications.AnnouncementDismissal do
      define(:dismiss_announcement, action: :dismiss)

      define(:list_dismissed_announcement_ids,
        action: :dismissed_ids_for_merchant,
        args: [:merchant_id]
      )
    end
  end

  @doc "Broadcast a notification to a user via PubSub."
  def broadcast_to_user(user_id, notification) do
    Phoenix.PubSub.broadcast(
      Emakola.PubSub,
      "user_notifications:#{user_id}",
      {:new_notification, notification}
    )
  end
end
