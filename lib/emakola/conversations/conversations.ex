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

  alias Emakola.Conversations.{Message, Thread}

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

  @doc "A store's buyer threads, most recently active first."
  def list_shop_threads(store_id) when is_binary(store_id) do
    Thread
    |> Ash.Query.for_read(:for_store, %{store_id: store_id})
    |> Ash.read(authorize?: false)
  end

  @doc "Posts a message and stamps the thread so inboxes sort correctly."
  def post_message(%Thread{} = thread, author_kind, author_id, body)
      when author_kind in [:merchant, :customer, :platform] do
    body = String.trim(body || "")

    with {:ok, message} <- create_message(thread, author_kind, author_id, body) do
      thread
      |> Ash.Changeset.for_update(:touch, %{last_message_at: message.inserted_at})
      |> Ash.update(authorize?: false)

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

  @doc "Marks everything currently in the thread as seen by `side`."
  def mark_read(%Thread{} = thread, :merchant) do
    thread
    |> Ash.Changeset.for_update(:mark_merchant_read, %{})
    |> Ash.update(authorize?: false)
  end

  def mark_read(%Thread{} = thread, side) when side in [:customer, :platform] do
    thread
    |> Ash.Changeset.for_update(:mark_counterpart_read, %{})
    |> Ash.update(authorize?: false)
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
end
