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

  import EmakolaWeb.ChatComponents

  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Messages",
       active_nav: :messages,
       query: "",
       # to_form without :as keeps the input's bare name ("q"), so
       # handle_event("search", %{"q" => _}) is unchanged. The guard tests
       # forbid raw form tags in admin/platform LiveViews.
       search_form: to_form(%{"q" => ""})
     )}
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

  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, query: query)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # One flash per cause. Telling someone who has been rate limited to "write
  # something first" sends them retyping a message that was never the problem.
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
      # The merchant is looking at it, so it is read on arrival.
      Conversations.mark_read(thread, :merchant)

      {:noreply,
       socket
       |> append_message(message)
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

      <div :if={@threads == []} class="bg-white border border-border rounded-card p-12 text-center">
        <div class="w-16 h-16 rounded-card bg-primary-soft flex items-center justify-center mx-auto mb-5">
          <.icon name="hero-chat-bubble-left-right" class="size-8 text-primary" />
        </div>
        <p class="text-lg font-semibold text-slate-900">No messages yet</p>
        <p class="text-sm text-slate-500 mt-2">When a buyer writes to you, it appears here.</p>
      </div>

      <div
        :if={@threads != []}
        class="grid grid-cols-1 lg:grid-cols-[330px_minmax(0,1fr)] bg-white rounded-card overflow-hidden shadow-lg shadow-slate-900/5 ring-1 ring-slate-200/60 lg:h-[calc(100vh-15rem)] lg:min-h-[480px]"
      >
        <%!-- Chats pane --%>
        <div class="flex flex-col border-b lg:border-b-0 lg:border-r border-slate-100 min-h-0">
          <div class="flex items-center gap-3 px-4 py-3.5 border-b border-slate-100 shrink-0">
            <.initials_avatar :if={@current_store} name={@current_store.name} />
            <.form for={@search_form} id="inbox-search" phx-change="search" class="flex-1">
              <input
                type="search"
                name="q"
                value={@query}
                placeholder="Search…"
                autocomplete="off"
                aria-label="Search conversations"
                class="w-full rounded-full border border-slate-200 bg-white px-4 py-2 text-[13px] text-slate-700 placeholder:text-slate-400 focus:border-emerald-500 focus:ring-emerald-500"
              />
            </.form>
          </div>

          <div id="chat-list" class="flex-1 overflow-y-auto min-h-0 px-3 py-3.5">
            <p class="px-2 mb-2.5 text-[15px] font-bold text-emerald-600">Chats</p>

            <.link
              :for={
                %{thread: thread, name: name, last: last, unread: unread} <-
                  visible_threads(@threads, @query)
              }
              navigate={~p"/admin/messages/#{thread.id}"}
              class={[
                "flex items-center gap-3 rounded-xl px-3 py-2.5 transition-colors",
                if(@thread && @thread.id == thread.id,
                  do:
                    "bg-gradient-to-br from-emerald-600 to-emerald-700 shadow-lg shadow-emerald-600/30",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <.thread_avatar thread={thread} name={name} />
              <div class="min-w-0 flex-1">
                <div class="flex items-baseline justify-between gap-2">
                  <p class={[
                    "truncate text-[13.5px]",
                    cond do
                      @thread && @thread.id == thread.id -> "font-semibold text-white"
                      unread > 0 -> "font-bold text-slate-900"
                      true -> "font-semibold text-slate-900"
                    end
                  ]}>
                    {name}
                  </p>
                  <span
                    :if={last}
                    class={[
                      "shrink-0 text-[10.5px]",
                      if(@thread && @thread.id == thread.id,
                        do: "text-white/75",
                        else: "text-slate-400"
                      )
                    ]}
                  >
                    {EmakolaWeb.LayoutHelpers.relative_time(last.inserted_at)}
                  </span>
                </div>
                <div class="flex items-center justify-between gap-2 mt-0.5">
                  <p class={[
                    "truncate text-xs",
                    if(@thread && @thread.id == thread.id,
                      do: "text-white/80",
                      else: "text-slate-500"
                    )
                  ]}>
                    {(last && last.body) || "Say hello"}
                  </p>
                  <span
                    :if={unread > 0 && !(@thread && @thread.id == thread.id)}
                    class="shrink-0 flex min-w-[18px] h-[18px] px-1 items-center justify-center rounded-full bg-emerald-600 text-white text-[10px] font-bold"
                  >
                    {unread}
                  </span>
                </div>
              </div>
            </.link>
          </div>
        </div>

        <%!-- Thread pane --%>
        <div :if={@thread} class="flex flex-col min-h-0 bg-slate-50">
          <div class="flex items-center gap-3 px-5 py-3 bg-white border-b border-slate-100 shrink-0">
            <.thread_avatar thread={@thread} name={thread_name(@thread)} />
            <div class="min-w-0 flex-1">
              <p class="text-sm font-bold text-slate-900 truncate">{thread_name(@thread)}</p>
              <p class="text-[11.5px] text-slate-400">
                {if @thread.kind == :platform_merchant,
                  do: "Makola support",
                  else: "Buyer on your shop"}
              </p>
            </div>
          </div>

          <div id="messages" class="flex-1 min-h-0 px-5 py-5 space-y-4 overflow-y-auto">
            <.chat_group
              :for={group <- group_messages(@messages)}
              group={group}
              own?={group.author_kind == :merchant}
              read_at={@thread.counterpart_last_read_at}
            >
              <:avatar>
                <.initials_avatar
                  :if={group.author_kind == :merchant && @current_store}
                  name={@current_store.name}
                  size="size-8"
                  text="text-[11px]"
                />
                <.thread_avatar
                  :if={group.author_kind != :merchant}
                  thread={@thread}
                  name={thread_name(@thread)}
                  size="size-8"
                  text="text-[11px]"
                />
              </:avatar>
            </.chat_group>
          </div>

          <.form for={@form} id="message-form" phx-submit="send">
            <.chat_composer form={@form} />
          </.form>
        </div>

        <div
          :if={is_nil(@thread)}
          class="hidden lg:flex flex-col items-center justify-center gap-3 bg-slate-50 p-12 text-center"
        >
          <div class="flex size-14 items-center justify-center rounded-full bg-white shadow-sm">
            <.icon name="hero-chat-bubble-left-right" class="size-7 text-slate-300" />
          </div>
          <p class="text-sm text-slate-500">Pick a message to read it.</p>
        </div>
      </div>
    </div>
    """
  end

  # Initials on a warm ring for buyers; the canopy gold marks Makola's own
  # thread apart from customer threads at a glance.
  attr :thread, :map, required: true
  attr :name, :string, required: true
  attr :size, :string, default: "size-10"
  attr :text, :string, default: "text-sm"

  defp thread_avatar(assigns) do
    ~H"""
    <span
      :if={@thread.kind == :platform_merchant}
      class={[
        "flex shrink-0 items-center justify-center rounded-full bg-[#d4a843]/15 ring-1 ring-[#d4a843]/40",
        @size
      ]}
    >
      <svg viewBox="0 0 64 64" class="size-5" aria-hidden="true">
        <path d="M32 8 L60 26 H4 Z" fill="#0c1f17" />
        <path
          d="M4 26 H60 V33 A5.6 5.6 0 0 1 48.8 33 A5.6 5.6 0 0 1 37.6 33 A5.6 5.6 0 0 1 26.4 33 A5.6 5.6 0 0 1 15.2 33 A5.6 5.6 0 0 1 4 33 Z"
          fill="#d4a843"
        />
        <rect x="8" y="46" width="48" height="10" rx="5" fill="#d4a843" />
      </svg>
    </span>
    <span
      :if={@thread.kind != :platform_merchant}
      class={[
        "flex shrink-0 items-center justify-center rounded-full bg-emerald-100 font-bold text-emerald-800",
        @size,
        @text
      ]}
    >
      {@name |> String.first() |> String.upcase()}
    </span>
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

  defp visible_threads(threads, ""), do: threads

  defp visible_threads(threads, query) do
    needle = String.downcase(query)
    Enum.filter(threads, fn %{name: name} -> String.contains?(String.downcase(name), needle) end)
  end

  defp thread_name(%{kind: :platform_merchant}), do: "Makola"
  defp thread_name(thread), do: buyer_name(thread)

  defp buyer_name(%{customer: %{name: name}}) when is_binary(name) and name != "", do: name
  defp buyer_name(_thread), do: "Buyer"
end
