defmodule EmakolaWeb.Admin.MessageLive do
  @moduledoc """
  The merchant's inbox for talking to their buyers.

  Every message here is free. The same conversation over SMS costs the
  merchant on each send, which is the whole reason this exists.

  Opening a thread marks it read — a merchant reading a message *is* the
  receipt, and asking them to press a second button to say "yes, I read it"
  would be a control that earns nothing.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Messages", active_nav: :messages)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    store = socket.assigns[:current_store]

    if store do
      {:noreply, socket |> load_threads(store) |> load_thread(params["id"], store)}
    else
      {:noreply, assign(socket, threads: [], thread: nil, messages: [], form: blank_form())}
    end
  end

  defp blank_form, do: to_form(%{"body" => ""}, as: :message)

  defp load_threads(socket, store) do
    {:ok, threads} = Conversations.list_shop_threads(store.id)
    # One query for every badge, rather than one per row.
    counts = Conversations.unread_counts(store.id, :merchant)

    rows =
      Enum.map(threads, fn thread ->
        %{
          thread: thread,
          name: buyer_name(thread),
          last: Conversations.last_message(thread.id),
          unread: Map.get(counts, thread.id, 0)
        }
      end)

    # Makola's own thread rides in the same inbox, first — a merchant should
    # not have to learn a second place to find messages.
    rows = platform_row(socket) ++ rows

    assign(socket,
      unread_total: Enum.sum(Enum.map(rows, & &1.unread)),
      threads: rows
    )
  end

  defp platform_row(socket) do
    with %{id: merchant_id} <- socket.assigns[:current_merchant],
         %{} = thread <- Conversations.platform_thread_for(merchant_id) do
      [
        %{
          thread: thread,
          name: "Makola",
          last: Conversations.last_message(thread.id),
          unread: Conversations.unread_count(thread.id, :merchant)
        }
      ]
    else
      _ -> []
    end
  end

  defp load_thread(socket, nil, _store) do
    assign(socket, thread: nil, messages: [], form: blank_form())
  end

  defp load_thread(socket, thread_id, store) do
    case resolve_thread(socket, store, thread_id) do
      {:ok, thread} ->
        if connected?(socket), do: Conversations.subscribe(thread.id)

        # Opening is reading.
        {:ok, thread} = Conversations.mark_read(thread, :merchant)
        {:ok, messages} = Conversations.list_messages(thread.id)
        thread = Ash.load!(thread, [:customer], authorize?: false)

        assign(socket, thread: thread, messages: messages, form: blank_form())

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "That conversation is not in your shop.")
        |> push_navigate(to: ~p"/admin/messages")
    end
  end

  # A merchant reaching Makola first. Their thread rode in this inbox from the
  # start, but only once it existed — and only staff could create one, so a
  # merchant with a question had nowhere to ask it.
  #
  # The merchant comes from the session, never a parameter, so this can only
  # ever open the caller's own thread. Opening is idempotent.
  @impl true
  def handle_event("contact_makola", _params, socket) do
    case socket.assigns[:current_merchant] do
      %{id: merchant_id} ->
        case Conversations.open_platform_thread(merchant_id) do
          {:ok, thread} ->
            {:noreply, push_navigate(socket, to: ~p"/admin/messages/#{thread.id}")}

          _ ->
            {:noreply, put_flash(socket, :error, "Could not open that conversation.")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    thread = socket.assigns.thread
    merchant = socket.assigns.current_merchant

    case Conversations.post_message(thread, :merchant, merchant.id, body) do
      {:ok, _message} ->
        {:ok, messages} = Conversations.list_messages(thread.id)

        {:noreply,
         socket
         |> assign(messages: messages, form: blank_form())
         |> load_threads(socket.assigns.current_store)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, send_error_message(reason))}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # One flash per cause. Telling someone who has been rate limited to "write
  # something first" sends them retyping a message that was never the problem.
  defp send_error_message(:empty_message), do: "Write something first."
  defp send_error_message(:rate_limited), do: "You are sending too fast. Wait a moment."
  defp send_error_message(_other), do: "That message did not send. Try again."

  @impl true
  def handle_info({:new_message, message}, socket) do
    thread = socket.assigns[:thread]

    if thread && message.thread_id == thread.id do
      # The merchant is looking at it, so it is read on arrival.
      Conversations.mark_read(thread, :merchant)

      {:noreply,
       socket
       |> assign(messages: socket.assigns.messages ++ [message])
       |> load_threads(socket.assigns.current_store)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1400px] mx-auto px-4 sm:px-6">
      <.admin_page_header
        icon="hero-chat-bubble-left-right"
        title="Messages"
        subtitle="Talk to your buyers. These messages are free."
      />

      <%!-- Always available, not only when the inbox is empty: the question a
            merchant needs to ask Makola rarely arrives on a quiet day. --%>
      <div class="flex justify-end -mt-2 mb-4">
        <button
          type="button"
          phx-click="contact_makola"
          class="inline-flex items-center gap-2 rounded-control border border-border bg-white hover:bg-surface-subtle px-4 py-2.5 text-sm font-semibold text-slate-700 transition-colors cursor-pointer"
        >
          <.icon name="hero-lifebuoy" class="size-4 text-primary" /> Ask Makola for help
        </button>
      </div>

      <div
        :if={@threads == []}
        class="bg-white border border-border rounded-card p-12 text-center"
      >
        <div class="w-16 h-16 rounded-card bg-primary-soft flex items-center justify-center mx-auto mb-5">
          <.icon name="hero-chat-bubble-left-right" class="size-8 text-primary" />
        </div>
        <p class="text-lg font-semibold text-slate-900">No messages yet</p>
        <p class="text-sm text-slate-500 mt-2">When a buyer writes to you, it appears here.</p>
      </div>

      <div :if={@threads != []} class="grid grid-cols-1 lg:grid-cols-[320px_minmax(0,1fr)] gap-6">
        <%!-- Inbox --%>
        <div class="space-y-2">
          <.link
            :for={%{thread: thread, name: name, last: last, unread: unread} <- @threads}
            navigate={~p"/admin/messages/#{thread.id}"}
            class={[
              "block rounded-card border p-4 transition-colors",
              if(@thread && @thread.id == thread.id,
                do: "border-primary bg-primary-soft",
                else: "border-border bg-white hover:border-slate-300"
              )
            ]}
          >
            <div class="flex items-center justify-between gap-2">
              <p class="font-semibold text-slate-900 truncate">{name}</p>
              <span
                :if={unread > 0}
                class="shrink-0 min-w-5 h-5 px-1.5 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center"
              >
                {unread}
              </span>
            </div>
            <p :if={last} class="text-sm text-slate-500 truncate mt-1">{last.body}</p>
          </.link>
        </div>

        <%!-- Thread --%>
        <div :if={@thread} class="bg-white border border-border rounded-card flex flex-col">
          <div class="px-5 py-4 border-b border-border">
            <p class="font-semibold text-slate-900">{thread_name(@thread)}</p>
          </div>

          <div id="messages" class="flex-1 p-5 space-y-3 max-h-[60vh] overflow-y-auto">
            <div
              :for={message <- @messages}
              id={"message-#{message.id}"}
              class={["flex", if(message.author_kind == :merchant, do: "justify-end", else: "")]}
            >
              <div class={[
                "max-w-[75%] rounded-card px-4 py-2.5 text-sm",
                if(message.author_kind == :merchant,
                  do: "bg-primary text-white",
                  else: "bg-slate-100 text-slate-900"
                )
              ]}>
                {message.body}
              </div>
            </div>
          </div>

          <.form for={@form} id="message-form" phx-submit="send" class="p-4 border-t border-border">
            <div class="flex items-end gap-3">
              <div class="flex-1">
                <.input field={@form[:body]} label="Your reply" placeholder="Type your message" />
              </div>
              <.admin_button type="submit">
                <.icon name="hero-paper-airplane" class="size-5" /> Send
              </.admin_button>
            </div>
          </.form>
        </div>

        <div
          :if={is_nil(@thread)}
          class="bg-white border border-border rounded-card p-12 text-center self-start"
        >
          <p class="text-sm text-slate-500">Pick a conversation to read it.</p>
        </div>
      </div>
    </div>
    """
  end

  # A merchant may open their own buyer threads or their own Makola thread,
  # and nothing else. Both lookups are scoped by something the merchant owns
  # — the store, or their own id — never by the id in the URL alone.
  defp resolve_thread(socket, store, thread_id) do
    case Conversations.get_shop_thread(store.id, thread_id) do
      {:ok, thread} ->
        {:ok, thread}

      {:error, :not_found} ->
        merchant = socket.assigns[:current_merchant]
        own = merchant && Conversations.platform_thread_for(merchant.id)

        if own && own.id == thread_id, do: {:ok, own}, else: {:error, :not_found}
    end
  end

  defp thread_name(%{kind: :platform_merchant}), do: "Makola"
  defp thread_name(thread), do: buyer_name(thread)

  defp buyer_name(%{customer: %{name: name}}) when is_binary(name) and name != "", do: name
  defp buyer_name(_thread), do: "Buyer"
end
