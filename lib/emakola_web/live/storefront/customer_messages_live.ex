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

  import EmakolaWeb.ChatComponents

  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Messages", form: blank_form(), active: :shop)
     |> EmakolaWeb.ChatMedia.allow()
     |> load()}
  end

  defp blank_form, do: to_form(%{"body" => ""}, as: :message)

  # Two conversations, one page: the shop, and Makola. A complaint about the
  # shop — or about money the shop cannot see — has to go somewhere the shop
  # is not reading.
  defp load(socket) do
    case socket.assigns[:current_customer] do
      %{id: customer_id} -> load_thread(socket, socket.assigns.active, customer_id)
      _ -> assign(socket, thread: nil, messages: [])
    end
  end

  defp load_thread(socket, :platform, customer_id) do
    open(socket, Conversations.platform_customer_thread_for(customer_id))
  end

  defp load_thread(socket, :shop, customer_id) do
    with %{id: store_id} <- socket.assigns[:store],
         {:ok, threads} <- Conversations.list_shop_threads(store_id) do
      open(socket, Enum.find(threads, &(&1.customer_id == customer_id)))
    else
      _ -> assign(socket, thread: nil, messages: [])
    end
  end

  # Opened lazily on the first message, so a buyer who never writes leaves no
  # empty thread behind.
  defp open(socket, nil), do: assign(socket, thread: nil, messages: [])

  defp open(socket, thread) do
    if connected?(socket), do: Conversations.subscribe(thread.id)
    Conversations.mark_read(thread, :customer)
    {:ok, messages} = Conversations.list_messages(thread.id)

    assign(socket, thread: thread, messages: messages)
  end

  @impl true
  def handle_event("open_platform_thread", _params, socket) do
    {:noreply, socket |> assign(active: :platform) |> load()}
  end

  def handle_event("open_shop_thread", _params, socket) do
    {:noreply, socket |> assign(active: :shop) |> load()}
  end

  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    with %{id: customer_id} <- socket.assigns[:current_customer],
         {:ok, thread} <- open_for_send(socket, customer_id),
         attachments = EmakolaWeb.ChatMedia.consume(socket, thread.id),
         {:ok, _message} <-
           Conversations.post_message(thread, :customer, customer_id, body,
             attachments: attachments
           ) do
      {:noreply, socket |> assign(form: blank_form()) |> load()}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, send_error_message(reason))}
      _ -> {:noreply, put_flash(socket, :error, "That message did not send. Try again.")}
    end
  end

  def handle_event("validate_media", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_media", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :chat_media, ref)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp open_for_send(%{assigns: %{active: :platform}}, customer_id) do
    Conversations.open_platform_customer_thread(customer_id)
  end

  defp open_for_send(socket, customer_id) do
    case socket.assigns[:store] do
      %{id: store_id} -> Conversations.open_shop_thread(store_id, customer_id)
      _ -> :error
    end
  end

  # One flash per cause. A buyer told to "write something first" after being
  # rate limited retypes a message that was never the problem.
  defp send_error_message(:empty_message), do: "Write something first."
  defp send_error_message(:rate_limited), do: "You are sending too fast. Wait a moment."
  defp send_error_message(_other), do: "That message did not send. Try again."

  # The sender receives their own broadcast too; the submit already rendered
  # that message, so appending the echo would show it twice.
  defp append_message(socket, message) do
    if Enum.any?(socket.assigns.messages, &(&1.id == message.id)) do
      socket
    else
      assign(socket, messages: socket.assigns.messages ++ [message])
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    thread = socket.assigns[:thread]

    if thread && message.thread_id == thread.id do
      # The buyer is looking at the thread, so the shop's reply is read.
      Conversations.mark_read(thread, :customer)
      {:noreply, append_message(socket, message)}
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

      <%!-- A guest gets an invitation, never a composer that silently fails.
            The thread needs an identity to belong to. --%>
      <div
        :if={is_nil(@current_customer)}
        class="mt-6 flex flex-col items-center gap-4 rounded-2xl bg-white p-10 text-center shadow-lg shadow-slate-900/5 ring-1 ring-slate-200/60"
      >
        <div class="flex size-12 items-center justify-center rounded-full bg-emerald-50">
          <.icon name="hero-chat-bubble-left-right" class="size-6 text-emerald-600" />
        </div>
        <div>
          <p class="text-base font-bold text-slate-900">Sign in to message the shop</p>
          <p class="mt-1 text-sm text-slate-500">
            Your conversation stays saved to your account — free, no SMS needed.
          </p>
        </div>
        <div class="flex gap-2.5">
          <.link
            navigate={"/s/#{@store.slug}/login"}
            class="rounded-xl bg-emerald-600 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-700"
          >
            Sign in
          </.link>
          <.link
            navigate={"/s/#{@store.slug}/register"}
            class="rounded-xl border border-slate-200 bg-white px-5 py-2.5 text-sm font-semibold text-slate-700 transition-colors hover:border-slate-300"
          >
            Create account
          </.link>
        </div>
      </div>

      <%!-- Two conversations, one page: the shop, and Makola. A complaint
            about the shop has to go somewhere the shop is not reading. --%>
      <div :if={@current_customer} class="mt-5 flex gap-2">
        <button
          type="button"
          phx-click="open_shop_thread"
          class={[
            "rounded-full px-4 py-2 text-sm font-semibold transition-colors cursor-pointer",
            if(@active == :shop,
              do: "bg-emerald-600 text-white",
              else: "bg-white text-slate-600 ring-1 ring-slate-200 hover:ring-slate-300"
            )
          ]}
        >
          {@store.name}
        </button>
        <button
          type="button"
          phx-click="open_platform_thread"
          class={[
            "rounded-full px-4 py-2 text-sm font-semibold transition-colors cursor-pointer",
            if(@active == :platform,
              do: "bg-emerald-600 text-white",
              else: "bg-white text-slate-600 ring-1 ring-slate-200 hover:ring-slate-300"
            )
          ]}
        >
          Makola
        </button>
      </div>

      <div
        :if={@current_customer}
        class="mt-3 overflow-hidden rounded-2xl bg-white shadow-lg shadow-slate-900/5 ring-1 ring-slate-200/60"
      >
        <div class="flex items-center gap-3 border-b border-slate-100 bg-white px-5 py-3">
          <.initials_avatar name={counterpart_name(@active, @store)} />
          <div class="min-w-0">
            <p class="text-sm font-bold text-slate-900 truncate">
              {counterpart_name(@active, @store)}
            </p>
            <p :if={@active == :shop} class="text-[11.5px] text-slate-400">
              Replies land right here.
            </p>
            <p :if={@active == :platform} class="text-[11.5px] text-slate-400">
              The shop cannot read this.
            </p>
          </div>
        </div>

        <div
          id="customer-messages"
          class="max-h-[55vh] space-y-4 overflow-y-auto bg-slate-50 px-4 py-5 sm:px-5"
        >
          <div :if={@messages == []} class="flex flex-col items-center gap-2 py-8 text-center">
            <div class="flex size-11 items-center justify-center rounded-full bg-white shadow-sm">
              <.icon name="hero-chat-bubble-left-right" class="size-5 text-slate-300" />
            </div>
            <p class="text-sm text-slate-500">No messages yet. Write the first one.</p>
          </div>

          <.chat_group
            :for={group <- group_messages(@messages)}
            group={group}
            own?={group.author_kind == :customer}
            read_at={@thread && @thread.merchant_last_read_at}
            id_prefix="customer-message"
          >
            <:avatar>
              <.initials_avatar
                :if={group.author_kind == :customer}
                name={buyer_name(@current_customer)}
                size="size-8"
                text="text-[11px]"
              />
              <.initials_avatar
                :if={group.author_kind != :customer}
                name={counterpart_name(@active, @store)}
                size="size-8"
                text="text-[11px]"
              />
            </:avatar>
          </.chat_group>
        </div>

        <.form
          for={@form}
          id="customer-message-form"
          phx-submit="send"
          phx-change="validate_media"
        >
          <.chat_composer form={@form} media={@uploads.chat_media} />
        </.form>
      </div>
    </div>
    """
  end

  defp buyer_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp buyer_name(_customer), do: "You"

  defp counterpart_name(:platform, _store), do: "Makola"
  defp counterpart_name(_active, %{name: name}), do: name
  defp counterpart_name(_active, _store), do: "The shop"
end
