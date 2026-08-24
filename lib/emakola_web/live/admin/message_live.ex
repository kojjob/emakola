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

    assign(socket,
      threads:
        Enum.map(threads, fn thread ->
          %{thread: thread, last: Conversations.last_message(thread.id)}
        end)
    )
  end

  defp load_thread(socket, nil, _store) do
    assign(socket, thread: nil, messages: [], form: blank_form())
  end

  defp load_thread(socket, thread_id, store) do
    case Conversations.get_shop_thread(store.id, thread_id) do
      {:ok, thread} ->
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

  @impl true
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

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Write something first.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1400px] mx-auto px-4 sm:px-6">
      <.admin_page_header
        icon="hero-chat-bubble-left-right"
        title="Messages"
        subtitle="Talk to your buyers. These messages are free."
      />

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
            :for={%{thread: thread, last: last} <- @threads}
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
              <p class="font-semibold text-slate-900 truncate">{buyer_name(thread)}</p>
              <span
                :if={Conversations.unread_count(thread.id, :merchant) > 0}
                class="shrink-0 min-w-5 h-5 px-1.5 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center"
              >
                {Conversations.unread_count(thread.id, :merchant)}
              </span>
            </div>
            <p :if={last} class="text-sm text-slate-500 truncate mt-1">{last.body}</p>
          </.link>
        </div>

        <%!-- Thread --%>
        <div :if={@thread} class="bg-white border border-border rounded-card flex flex-col">
          <div class="px-5 py-4 border-b border-border">
            <p class="font-semibold text-slate-900">{buyer_name(@thread)}</p>
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

  defp buyer_name(%{customer: %{name: name}}) when is_binary(name) and name != "", do: name
  defp buyer_name(_thread), do: "Buyer"
end
