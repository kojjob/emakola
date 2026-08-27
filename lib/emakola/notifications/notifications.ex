defmodule Emakola.Notifications do
  @moduledoc "Notifications domain — SMS, WhatsApp, and email delivery with notification and email log resources."
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/v1")
  end

  resources do
    resource(Emakola.Notifications.DeviceToken)

    resource Emakola.Notifications.Notification do
      define(:list_notifications, action: :read)
      define(:mark_as_read, action: :mark_read)
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

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Notification

  @doc """
  Tells `recipient` something, and pushes it to their open pages.

  `recipient` is whichever actor struct the caller already holds — a
  `Merchant`, a `Customer`, or a platform `User`. Taking the struct rather
  than a bare id is what stops a caller pairing one actor's id with another's
  kind, which nothing in the database would catch.
  """
  def notify(recipient, type, attrs \\ %{}) do
    kind = recipient_kind(recipient)

    params =
      attrs
      |> Map.new()
      |> Map.merge(%{type: type, recipient_kind: kind, recipient_id: recipient.id})
      |> Map.update(:title, nil, &truncate_title/1)

    with {:ok, notification} <-
           Notification
           |> Ash.Changeset.for_create(:notify, params)
           |> Ash.create(authorize?: false) do
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        topic(kind, recipient.id),
        {:new_notification, notification}
      )

      {:ok, notification}
    end
  end

  @doc """
  Tells everyone who runs a store something.

  Notifications belong to people, not shops, and most platform events —
  payouts, verification, moderation — are keyed on a store. Every member is
  told, not just the owner: a shop where only the owner hears about a
  takedown is a shop where staff keep selling a delisted product.

  Never raises. A notification failing must not fail the delivery job that
  triggered it.
  """
  def notify_store(store_id, type, attrs \\ %{}) when is_binary(store_id) do
    shared =
      attrs
      |> Map.new()
      |> Map.merge(%{type: type, recipient_kind: :merchant})
      |> Map.update(:title, nil, &truncate_title/1)

    inputs =
      store_id
      |> store_merchants()
      |> Enum.map(&Map.put(shared, :recipient_id, &1.id))

    # One insert for the whole team, not one per member: this runs inline in
    # checkout's order_placed dispatch, where every extra round-trip sits
    # between the buyer tapping Pay and the confirmation screen.
    case inputs do
      [] ->
        :ok

      inputs ->
        inputs
        |> Ash.bulk_create(Notification, :notify,
          authorize?: false,
          return_records?: true,
          return_errors?: true
        )
        |> broadcast_bulk_result(type)
    end
  rescue
    exception ->
      Logger.error("[notifications] notify_store raised: #{Exception.message(exception)}")
      :ok
  end

  # A bulk create returns whatever rows it managed to insert even on partial
  # failure; each one still gets its real-time push, and each failure is
  # logged rather than dropped — no exception, no row, and a worker reporting
  # success is how a validation slip goes unnoticed. A title longer than the
  # column allows is the realistic case.
  defp broadcast_bulk_result(%Ash.BulkResult{records: records, errors: errors}, type) do
    Enum.each(records || [], fn notification ->
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        topic(:merchant, notification.recipient_id),
        {:new_notification, notification}
      )
    end)

    Enum.each(errors || [], fn error ->
      Logger.error("[notifications] #{inspect(type)} for store member failed: #{inspect(error)}")
    end)

    :ok
  end

  # Titles are built from user data — "#{product.title} was taken down" — and
  # the column caps at 255. Trimming here, at the one place every notification
  # passes through, rather than at each call site: refusing would mean a
  # merchant with a long product name silently gets no notification, and a
  # 300-character title was never going to render in a dropdown anyway.
  @title_limit 255

  defp truncate_title(title) when is_binary(title) do
    if String.length(title) > @title_limit do
      String.slice(title, 0, @title_limit - 1) <> "…"
    else
      title
    end
  end

  defp truncate_title(title), do: title

  defp store_merchants(store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, memberships} ->
        memberships
        |> Enum.map(& &1.merchant_id)
        |> Enum.uniq()
        |> read_merchants()

      _ ->
        []
    end
  end

  # One id-in-list read rather than a get per membership. Still a read of the
  # merchant table, not a shortcut through membership.merchant_id: a
  # membership row whose merchant no longer resolves must not be notified.
  defp read_merchants([]), do: []

  defp read_merchants(merchant_ids) do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(id in ^merchant_ids)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, merchants} -> merchants
      _ -> []
    end
  end

  @doc "A recipient's most recent notifications, newest first."
  def list_for(recipient) do
    Notification
    |> Ash.Query.for_read(:for_recipient, recipient_args(recipient))
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, notifications} -> notifications
      _ -> []
    end
  end

  @doc "How many of a recipient's notifications are still unread."
  def unread_count_for(recipient) do
    Notification
    |> Ash.Query.for_read(:unread_for_recipient, recipient_args(recipient))
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc "Marks one notification as read."
  def mark_read(%Notification{} = notification) do
    notification
    |> Ash.Changeset.for_update(:mark_read, %{})
    |> Ash.update(authorize?: false)
  end

  @doc """
  Clears a recipient's whole bell in one statement.

  A bulk update rather than a loop over loaded rows: emptying a bell should
  not cost one query per unread notification.
  """
  def mark_all_read_for(recipient) do
    Notification
    |> Ash.Query.for_read(:unread_for_recipient, recipient_args(recipient))
    |> Ash.bulk_update(:mark_all_read, %{}, authorize?: false, return_errors?: true)
    |> case do
      %Ash.BulkResult{status: :success} ->
        :ok

      # `:partial_success` means some rows cleared and some did not. Reporting
      # it as success would leave a badge showing zero over unread rows;
      # reporting only `errors` would read as a total failure.
      %Ash.BulkResult{status: :partial_success, errors: errors} ->
        Logger.error("[notifications] mark_all_read cleared only some rows: #{inspect(errors)}")
        {:error, errors}

      %Ash.BulkResult{errors: errors} ->
        {:error, errors}
    end
  end

  @doc "Subscribes the calling process to a recipient's new notifications."
  def subscribe(recipient) do
    Phoenix.PubSub.subscribe(Emakola.PubSub, topic(recipient_kind(recipient), recipient.id))
  end

  # The kind is part of the topic, not decoration: recipient_id carries no
  # foreign key, so two actors in different tables can hold the same uuid and
  # would otherwise share a channel.
  defp topic(kind, id), do: "notifications:#{kind}:#{id}"

  defp recipient_args(recipient) do
    %{recipient_kind: recipient_kind(recipient), recipient_id: recipient.id}
  end

  defp recipient_kind(%Emakola.Accounts.User{}), do: :user
  defp recipient_kind(%Emakola.Accounts.Merchant{}), do: :merchant
  defp recipient_kind(%Emakola.Customers.Customer{}), do: :customer
end
