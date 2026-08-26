defmodule EmakolaWeb.Storefront.CustomerMessagesLive do
  @moduledoc """
  The buyer's side: message the shop from inside their account.

  A buyer here needs no WhatsApp, no airtime and no SMS — the two people who
  need to talk are both already on the platform, so the conversation costs
  nobody anything.

  The thread is opened lazily on the first message. A buyer who never writes
  never creates a row, so a merchant's inbox lists conversations rather than
  every customer who ever browsed.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Messages", form: blank_form()) |> load()}
  end

  defp blank_form, do: to_form(%{"body" => ""}, as: :message)

  defp load(socket) do
    with %{id: customer_id} <- socket.assigns[:current_customer],
         %{id: store_id} <- socket.assigns[:store],
         {:ok, threads} <- Conversations.list_shop_threads(store_id) do
      thread = Enum.find(threads, &(&1.customer_id == customer_id))

      messages =
        case thread do
          nil ->
            []

          thread ->
            if connected?(socket), do: Conversations.subscribe(thread.id)
            Conversations.mark_read(thread, :customer)
            {:ok, messages} = Conversations.list_messages(thread.id)
            messages
        end

      assign(socket, thread: thread, messages: messages)
    else
      _ -> assign(socket, thread: nil, messages: [])
    end
  end

  @impl true
  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    customer = socket.assigns[:current_customer]
    store = socket.assigns[:store]

    with %{id: customer_id} <- customer,
         %{id: store_id} <- store,
         {:ok, thread} <- Conversations.open_shop_thread(store_id, customer_id),
         {:ok, _message} <- Conversations.post_message(thread, :customer, customer_id, body) do
      {:noreply, socket |> assign(form: blank_form()) |> load()}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, send_error_message(reason))}
      _ -> {:noreply, put_flash(socket, :error, "That message did not send. Try again.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # One flash per cause. A buyer told to "write something first" after being
  # rate limited retypes a message that was never the problem.
  defp send_error_message(:empty_message), do: "Write something first."
  defp send_error_message(:rate_limited), do: "You are sending too fast. Wait a moment."
  defp send_error_message(_other), do: "That message did not send. Try again."

  @impl true
  def handle_info({:new_message, message}, socket) do
    thread = socket.assigns[:thread]

    if thread && message.thread_id == thread.id do
      # The buyer is looking at the thread, so the shop's reply is read.
      Conversations.mark_read(thread, :customer)
      {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold text-slate-900">Message the shop</h1>
      <p class="text-sm text-slate-500 mt-2">Ask about your order. It is free to write here.</p>

      <div class="mt-6 bg-white border border-slate-200 rounded-2xl">
        <div id="customer-messages" class="p-5 space-y-3 max-h-[55vh] overflow-y-auto">
          <p :if={@messages == []} class="text-sm text-slate-500 text-center py-8">
            No messages yet. Write the first one.
          </p>

          <div
            :for={message <- @messages}
            id={"customer-message-#{message.id}"}
            class={["flex", if(message.author_kind == :customer, do: "justify-end", else: "")]}
          >
            <div class={[
              "max-w-[75%] rounded-2xl px-4 py-2.5 text-sm",
              if(message.author_kind == :customer,
                do: "bg-emerald-600 text-white",
                else: "bg-slate-100 text-slate-900"
              )
            ]}>
              {message.body}
            </div>
          </div>
        </div>

        <.form
          for={@form}
          id="customer-message-form"
          phx-submit="send"
          class="p-4 border-t border-slate-200 flex items-end gap-3"
        >
          <div class="flex-1">
            <.input field={@form[:body]} label="Your message" placeholder="Type your message" />
          </div>
          <button
            type="submit"
            class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
          >
            Send
          </button>
        </.form>
      </div>
    </div>
    """
  end
end
