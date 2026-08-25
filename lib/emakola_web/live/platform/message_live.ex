defmodule EmakolaWeb.Platform.MessageLive do
  @moduledoc """
  Makola staff talking to merchants.

  The same thread/message core as buyer messaging — only the two sides
  differ. Announcements broadcast at merchants; this is the conversation
  back, which is where a merchant tells you their payout is late.

  Staff see every merchant thread and need no scoping check: reaching this
  page at all requires platform staff. A merchant never opens a thread by
  id — theirs is found by their own merchant_id.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Messages", active_nav: :messages)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> load_threads() |> load_thread(params["id"])}
  end

  defp blank_form, do: to_form(%{"body" => ""}, as: :message)

  defp load_threads(socket) do
    {:ok, threads} = Conversations.list_platform_threads()

    assign(socket,
      threads:
        Enum.map(threads, fn thread ->
          %{
            thread: thread,
            last: Conversations.last_message(thread.id),
            unread: Conversations.unread_count(thread.id, :platform)
          }
        end)
    )
  end

  defp load_thread(socket, nil), do: assign(socket, thread: nil, messages: [], form: blank_form())

  defp load_thread(socket, thread_id) do
    case Conversations.get_platform_thread(thread_id) do
      {:ok, thread} ->
        if connected?(socket), do: Conversations.subscribe(thread.id)
        {:ok, thread} = Conversations.mark_read(thread, :platform)
        {:ok, messages} = Conversations.list_messages(thread.id)
        thread = Ash.load!(thread, [:merchant], authorize?: false)

        assign(socket, thread: thread, messages: messages, form: blank_form())

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "That conversation no longer exists.")
        |> push_navigate(to: ~p"/platform/messages")
    end
  end

  @impl true
  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    thread = socket.assigns.thread
    staff = socket.assigns.current_user

    case Conversations.post_message(thread, :platform, staff.id, body) do
      {:ok, _message} ->
        {:ok, messages} = Conversations.list_messages(thread.id)
        {:noreply, socket |> assign(messages: messages, form: blank_form()) |> load_threads()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Write something first.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:new_message, message}, socket) do
    thread = socket.assigns[:thread]

    if thread && message.thread_id == thread.id do
      Conversations.mark_read(thread, :platform)

      {:noreply,
       socket |> assign(messages: socket.assigns.messages ++ [message]) |> load_threads()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-[1400px] mx-auto">
      <div class="mb-6 flex items-center gap-4">
        <div class="w-13 h-13 rounded-card bg-primary flex items-center justify-center shrink-0 shadow-sm">
          <.icon name="hero-chat-bubble-left-right" class="size-7 text-white" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Messages</h1>
          <p class="text-sm text-gray-500 mt-1">Conversations with merchants.</p>
        </div>
      </div>

      <div :if={@threads == []} class="bg-white border border-gray-200 rounded-card p-12 text-center">
        <p class="text-lg font-semibold text-gray-900">No conversations yet</p>
        <p class="text-sm text-gray-500 mt-2">
          Open one from a merchant's page when you need to reach them.
        </p>
      </div>

      <div :if={@threads != []} class="grid grid-cols-1 lg:grid-cols-[320px_minmax(0,1fr)] gap-6">
        <div class="space-y-2">
          <.link
            :for={%{thread: thread, last: last, unread: unread} <- @threads}
            navigate={~p"/platform/messages/#{thread.id}"}
            class={[
              "block rounded-card border p-4 transition-colors",
              if(@thread && @thread.id == thread.id,
                do: "border-primary bg-primary-soft",
                else: "border-gray-200 bg-white hover:border-gray-300"
              )
            ]}
          >
            <div class="flex items-center justify-between gap-2">
              <p class="font-semibold text-gray-900 truncate">{merchant_name(thread)}</p>
              <span
                :if={unread > 0}
                class="shrink-0 min-w-5 h-5 px-1.5 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center"
              >
                {unread}
              </span>
            </div>
            <p :if={last} class="text-sm text-gray-500 truncate mt-1">{last.body}</p>
          </.link>
        </div>

        <div :if={@thread} class="bg-white border border-gray-200 rounded-card flex flex-col">
          <div class="px-5 py-4 border-b border-gray-200">
            <p class="font-semibold text-gray-900">{merchant_name(@thread)}</p>
          </div>

          <div id="messages" class="flex-1 p-5 space-y-3 max-h-[60vh] overflow-y-auto">
            <div
              :for={message <- @messages}
              id={"message-#{message.id}"}
              class={["flex", if(message.author_kind == :platform, do: "justify-end", else: "")]}
            >
              <div class={[
                "max-w-[75%] rounded-card px-4 py-2.5 text-sm",
                if(message.author_kind == :platform,
                  do: "bg-primary text-white",
                  else: "bg-gray-100 text-gray-900"
                )
              ]}>
                {message.body}
              </div>
            </div>
          </div>

          <.form
            for={@form}
            id="message-form"
            phx-submit="send"
            class="p-4 border-t border-gray-200 flex items-end gap-3"
          >
            <div class="flex-1">
              <.input field={@form[:body]} label="Your reply" placeholder="Type your message" />
            </div>
            <.admin_button type="submit">
              <.icon name="hero-paper-airplane" class="size-5" /> Send
            </.admin_button>
          </.form>
        </div>

        <div
          :if={is_nil(@thread)}
          class="bg-white border border-gray-200 rounded-card p-12 text-center self-start"
        >
          <p class="text-sm text-gray-500">Pick a conversation to read it.</p>
        </div>
      </div>
    </div>
    """
  end

  defp merchant_name(%{merchant: %{name: name}}) when is_binary(name) and name != "", do: name

  defp merchant_name(%{merchant: %{email: email}}) when not is_nil(email),
    do: to_string(email)

  defp merchant_name(_thread), do: "Merchant"
end
