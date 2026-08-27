defmodule Emakola.Conversations do
  @moduledoc """
  In-house messaging: a merchant with their buyers, and Makola with merchants.

  This exists to avoid paying per SMS for conversations that never need to
  leave the platform. A message here costs nothing; an SMS costs the merchant
  money on every send.

  Both directions share one thread/message core — see
  `Emakola.Conversations.Thread`.
  """

  use Ash.Domain

  alias Emakola.Conversations.{Message, MessageNudgeWorker, Thread}

  resources do
    resource(Thread)
    resource(Message)
  end

  @doc "The thread between a shop and one buyer. Idempotent."
  def open_shop_thread(store_id, customer_id)
      when is_binary(store_id) and is_binary(customer_id) do
    Thread
    |> Ash.Changeset.for_create(:open_shop, %{store_id: store_id, customer_id: customer_id})
    |> Ash.create(authorize?: false)
  end

  @doc "The thread between Makola and one merchant. Idempotent."
  def open_platform_thread(merchant_id) when is_binary(merchant_id) do
    Thread
    |> Ash.Changeset.for_create(:open_platform, %{merchant_id: merchant_id})
    |> Ash.create(authorize?: false)
  end

  @doc """
  The thread between Makola and one buyer. Idempotent.

  Separate from their shop thread: a complaint about the shop, or about money
  the shop cannot see, has nowhere else to go.
  """
  def open_platform_customer_thread(customer_id) when is_binary(customer_id) do
    Thread
    |> Ash.Changeset.for_create(:open_platform_customer, %{customer_id: customer_id})
    |> Ash.create(authorize?: false)
  end

  @doc "A buyer's own Makola thread, or nil."
  def platform_customer_thread_for(customer_id) when is_binary(customer_id) do
    Thread
    |> Ash.Query.for_read(:platform_for_customer, %{customer_id: customer_id})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, thread} -> thread
      _ -> nil
    end
  end

  @doc "A store's buyer threads, most recently active first."
  def list_shop_threads(store_id) when is_binary(store_id) do
    with {:ok, threads} <-
           Thread
           |> Ash.Query.for_read(:for_store, %{store_id: store_id})
           |> Ash.read(authorize?: false) do
      {:ok, Ash.load!(threads, [:customer], authorize?: false)}
    end
  end

  @doc "Every Makola ↔ merchant thread, most recently active first."
  def list_platform_threads do
    with {:ok, threads} <-
           Thread
           |> Ash.Query.for_read(:all_platform, %{})
           |> Ash.read(authorize?: false) do
      # Both sides loaded: a merchant thread has no customer and a customer
      # thread has no merchant, so the inbox reads whichever is set.
      {:ok, Ash.load!(threads, [:merchant, :customer], authorize?: false)}
    end
  end

  @doc """
  A merchant's own Makola thread, or nil.

  Returns nil rather than creating one: a merchant who has never been
  written to should see no support conversation at all, not an empty one.
  """
  def platform_thread_for(merchant_id) when is_binary(merchant_id) do
    Thread
    |> Ash.Query.for_read(:platform_for_merchant, %{merchant_id: merchant_id})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, thread} -> thread
      _ -> nil
    end
  end

  @doc """
  A platform thread by id — staff-only, so no scoping argument.

  Merchants never reach this: their own thread is found by merchant_id.
  """
  def get_platform_thread(thread_id) when is_binary(thread_id) do
    case Ash.get(Thread, thread_id, authorize?: false) do
      {:ok, %Thread{kind: :platform_merchant} = thread} ->
        {:ok, Ash.load!(thread, [:merchant], authorize?: false)}

      _ ->
        {:error, :not_found}
    end
  end

  @doc "The last thing said in a thread, for an inbox preview."
  def last_message(thread_id) when is_binary(thread_id) do
    case list_messages(thread_id) do
      {:ok, []} -> nil
      {:ok, messages} -> List.last(messages)
      _ -> nil
    end
  end

  @doc """
  A shop thread, but only if it belongs to `store_id`.

  Scoped rather than a bare `Ash.get/2`: the thread id travels in the URL, so
  the only thing standing between a merchant and another shop's conversation
  is this check.
  """
  def get_shop_thread(store_id, thread_id) when is_binary(store_id) and is_binary(thread_id) do
    case Ash.get(Thread, thread_id, authorize?: false) do
      {:ok, %Thread{store_id: ^store_id, kind: :shop_buyer} = thread} -> {:ok, thread}
      _ -> {:error, :not_found}
    end
  end

  # Generous for a person typing and useless to a script. The two ceilings
  # differ because the two sides fan out differently: a buyer has one thread
  # per shop and never needs more than a conversational pace, while a merchant
  # clearing a morning's worth of waiting buyers legitimately posts to dozens
  # of threads in a minute. One shared ceiling would either be too loose to
  # stop a script or tight enough to silence a merchant mid-shift.
  @buyer_message_limit 30
  @staff_message_limit 240
  @message_window_ms 60_000

  @doc "How many messages an author of `kind` may post per minute."
  def message_limit(kind \\ :customer)
  def message_limit(:customer), do: @buyer_message_limit
  def message_limit(kind) when kind in [:merchant, :platform], do: @staff_message_limit

  @doc """
  Posts a message and stamps the thread so inboxes sort correctly.

  Returns `{:error, :rate_limited}` when the author has been writing faster
  than a person plausibly types. The allowance is per author rather than per
  thread, so one abusive buyer cannot spend a shop's other conversations.
  """
  def post_message(%Thread{} = thread, author_kind, author_id, body)
      when author_kind in [:merchant, :customer, :platform] do
    body = String.trim(body || "")

    with :ok <- check_message_rate(author_kind, author_id),
         {:ok, message} <- create_message(thread, author_kind, author_id, body) do
      thread
      |> Ash.Changeset.for_update(:touch, %{last_message_at: message.inserted_at})
      |> Ash.update(authorize?: false)

      Phoenix.PubSub.broadcast(Emakola.PubSub, topic(thread.id), {:new_message, message})
      broadcast_store_change(thread)
      notify_other_side(thread, author_kind)
      schedule_nudge(thread, author_kind)

      {:ok, message}
    end
  end

  @doc "A thread's messages, oldest first."
  def list_messages(thread_id) when is_binary(thread_id) do
    Message
    |> Ash.Query.for_read(:for_thread, %{thread_id: thread_id})
    |> Ash.read(authorize?: false)
  end

  @doc """
  How many messages `side` has not seen.

  A side never counts its own messages — you have read what you wrote.
  """
  def unread_count(thread_id, side) when side in [:merchant, :customer, :platform] do
    with {:ok, thread} <- Ash.get(Thread, thread_id, authorize?: false) do
      since = last_read_at(thread, side)

      Message
      |> Ash.Query.for_read(:unread_for_thread, %{
        thread_id: thread_id,
        since: since,
        exclude_kind: side
      })
      |> Ash.read(authorize?: false)
      |> case do
        {:ok, rows} -> length(rows)
        _ -> 0
      end
    else
      _ -> 0
    end
  end

  @doc """
  Unread counts for every thread in a store, as `%{thread_id => count}`.

  One query for the whole inbox. `unread_count/2` is per-thread and fine for
  a single open conversation; calling it once per row turns an inbox into N
  queries, which is invisible at ten conversations and painful at a thousand.
  """
  def unread_counts(store_id, side) when is_binary(store_id) do
    with {:ok, threads} <- list_shop_threads(store_id),
         ids when ids != [] <- Enum.map(threads, & &1.id),
         {:ok, messages} <-
           Message
           |> Ash.Query.for_read(:for_threads, %{thread_ids: ids})
           |> Ash.read(authorize?: false) do
      read_marks = Map.new(threads, &{&1.id, last_read_at(&1, side)})

      counts =
        messages
        |> Enum.filter(fn message ->
          message.author_kind != side and
            unread?(message.inserted_at, Map.get(read_marks, message.thread_id))
        end)
        |> Enum.frequencies_by(& &1.thread_id)

      # Threads with nothing unread still belong in the map, so a caller can
      # read every thread's count without a nil check.
      Map.new(threads, &{&1.id, Map.get(counts, &1.id, 0)})
    else
      _ -> %{}
    end
  end

  @doc """
  How many messages across a store's whole inbox the merchant has not read.

  One aggregate query, so the sidebar badge costs the same on a shop with ten
  conversations and a shop with ten thousand messages.
  """
  def unread_total_for_store(store_id) when is_binary(store_id) do
    Message
    |> Ash.Query.for_read(:unread_for_store, %{store_id: store_id})
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc "Subscribes the calling process to a thread's new messages."
  def subscribe(thread_id) when is_binary(thread_id) do
    Phoenix.PubSub.subscribe(Emakola.PubSub, topic(thread_id))
  end

  @doc """
  Subscribes to anything that changes a store's unread total.

  Separate from `subscribe/1` because the sidebar badge is a store-wide
  number: a merchant looking at the dashboard is subscribed to no individual
  conversation, so the per-thread topic cannot reach them.
  """
  def subscribe_store(store_id) when is_binary(store_id) do
    Phoenix.PubSub.subscribe(Emakola.PubSub, store_topic(store_id))
  end

  @doc "Marks everything currently in the thread as seen by `side`."
  def mark_read(%Thread{} = thread, :merchant) do
    result =
      thread
      |> Ash.Changeset.for_update(:mark_merchant_read, %{})
      |> Ash.update(authorize?: false)

    # Reading is the other half of the badge: opening a conversation has to
    # drop the count as promptly as a new message raises it.
    with {:ok, _} <- result, do: broadcast_store_change(thread)

    result
  end

  def mark_read(%Thread{} = thread, side) when side in [:customer, :platform] do
    thread
    |> Ash.Changeset.for_update(:mark_counterpart_read, %{})
    |> Ash.update(authorize?: false)
  end

  defp check_message_rate(author_kind, author_id) do
    key = "conversation_post:#{author_kind}:#{author_id}"

    case Emakola.RateLimit.check_rate(key, message_limit(author_kind), @message_window_ms) do
      {:allow, _count} -> :ok
      {:deny, _retry_after_ms} -> {:error, :rate_limited}
    end
  end

  defp create_message(_thread, _kind, _id, ""), do: {:error, :empty_message}

  defp create_message(thread, author_kind, author_id, body) do
    Message
    |> Ash.Changeset.for_create(:post, %{
      thread_id: thread.id,
      author_kind: author_kind,
      author_id: author_id,
      body: body
    })
    |> Ash.create(authorize?: false)
  end

  # The merchant is one side; the buyer (shop thread) or Makola staff
  # (platform thread) is the other.
  defp last_read_at(thread, :merchant), do: thread.merchant_last_read_at
  defp last_read_at(thread, _counterpart), do: thread.counterpart_last_read_at

  # Never read means everything from the other side is unread.
  defp unread?(_inserted_at, nil), do: true
  defp unread?(inserted_at, since), do: DateTime.compare(inserted_at, since) == :gt

  defp topic(thread_id), do: "conversation:" <> thread_id

  defp store_topic(store_id), do: "store:#{store_id}:messages"

  # Only shop threads belong to a store. A merchant's Makola support thread
  # carries no store_id and must not raise a shop's buyer badge.
  defp broadcast_store_change(%Thread{kind: :shop_buyer, store_id: store_id})
       when is_binary(store_id) do
    Phoenix.PubSub.broadcast(Emakola.PubSub, store_topic(store_id), :store_messages_changed)
  end

  defp broadcast_store_change(_thread), do: :ok

  # An in-app bell for the side that did not write, immediately. This is the
  # free half of telling someone: the SMS nudge below still waits ten minutes
  # and still costs money, and is skipped entirely if the bell did its job and
  # they read it in time.
  defp notify_other_side(%Thread{kind: :shop_buyer} = thread, :customer) do
    with {:ok, customer} <- fetch(Emakola.Customers.Customer, thread.customer_id) do
      Emakola.Notifications.notify_store(thread.store_id, :new_message, %{
        title: "#{customer.name || "A buyer"} sent you a message",
        action_url: "/admin/messages/#{thread.id}"
      })
    end

    :ok
  end

  defp notify_other_side(%Thread{kind: :shop_buyer} = thread, :merchant) do
    with {:ok, customer} <- fetch(Emakola.Customers.Customer, thread.customer_id),
         {:ok, store} <- fetch(Emakola.Stores.Store, thread.store_id) do
      Emakola.Notifications.notify(customer, :new_message, %{
        title: "#{store.name} replied to you",
        action_url: "/account/messages"
      })
    end

    :ok
  end

  defp notify_other_side(%Thread{kind: :platform_customer} = thread, :platform) do
    with {:ok, customer} <- fetch(Emakola.Customers.Customer, thread.customer_id) do
      Emakola.Notifications.notify(customer, :new_message, %{
        title: "Makola replied to you",
        action_url: "/account/messages"
      })
    end

    :ok
  end

  defp notify_other_side(%Thread{kind: :platform_merchant} = thread, :platform) do
    with {:ok, merchant} <- fetch(Emakola.Accounts.Merchant, thread.merchant_id) do
      Emakola.Notifications.notify(merchant, :new_message, %{
        title: "Makola sent you a message",
        action_url: "/admin/messages/#{thread.id}"
      })
    end

    :ok
  end

  # Staff read the dashboard, not a bell — the same reason MessageNudgeWorker
  # never sends them an SMS.
  defp notify_other_side(_thread, _author_kind), do: :ok

  defp fetch(resource, nil) when is_atom(resource), do: :error

  defp fetch(resource, id) do
    case Ash.get(resource, id, authorize?: false) do
      {:ok, record} -> {:ok, record}
      _ -> :error
    end
  end

  # Tell the OTHER side, later, and only if they still have not read it. The
  # delay plus Oban uniqueness is what stops a free in-app conversation from
  # billing the merchant for an SMS per message.
  defp schedule_nudge(thread, author_kind) do
    case other_side(thread, author_kind) do
      nil ->
        :ok

      side ->
        %{"thread_id" => thread.id, "side" => to_string(side)}
        |> MessageNudgeWorker.new(schedule_in: MessageNudgeWorker.delay_seconds())
        |> Oban.insert()

        :ok
    end
  end

  # Staff are never nudged — they work in the dashboard — so a merchant
  # writing on a platform thread schedules nothing.
  defp other_side(%Thread{kind: :platform_merchant}, :platform), do: :merchant
  defp other_side(%Thread{kind: :platform_merchant}, _author), do: nil
  # Staff are never nudged, so a buyer writing to Makola schedules nothing.
  defp other_side(%Thread{kind: :platform_customer}, :platform), do: :customer
  defp other_side(%Thread{kind: :platform_customer}, _author), do: nil
  defp other_side(%Thread{kind: :shop_buyer}, :merchant), do: :customer
  defp other_side(%Thread{kind: :shop_buyer}, :customer), do: :merchant
  defp other_side(_thread, _author), do: nil
end
