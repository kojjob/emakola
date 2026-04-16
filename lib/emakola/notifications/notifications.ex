defmodule Emakola.Notifications do
  @moduledoc "Notifications domain — SMS, WhatsApp, and email delivery with notification and email log resources."
  use Ash.Domain

  resources do
    resource Emakola.Notifications.Notification do
      define(:create_notification, action: :create)
      define(:list_notifications, action: :read)
      define(:mark_as_read, action: :mark_read)
      define(:mark_all_read, action: :mark_all_read)
    end

    resource Emakola.Notifications.EmailLog do
      define(:create_email_log, action: :create)
      define(:list_email_logs, action: :read)
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
