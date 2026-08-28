defmodule EmakolaWeb.Platform.MessageLive do
  @moduledoc """
  Makola staff talking to merchants.

  The same thread/message core as buyer messaging — only the two sides
  differ. Announcements broadcast at merchants; this is the conversation
  back, which is where a merchant tells you their payout is late.

  Staff see every merchant thread and need no scoping check, so the gate is
  the whole access control: `:manage_merchants`, the same permission that
  guards the merchant directory this conversation is started from. A merchant
  never opens a thread by id — theirs is found by their own merchant_id.

  Being platform staff is not enough on its own. These threads carry whatever
  a merchant chose to tell Makola in confidence, and someone trusted with
  billing has no business reading it.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

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

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, send_error_message(reason))}
    end
  end

  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, query: query)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # One flash per cause — a collapsed error tells staff nothing about why the
  # message did not go.
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
      Conversations.mark_read(thread, :platform)

      {:noreply, socket |> append_message(message) |> load_threads()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 sm:p-6 max-w-[1400px] mx-auto h-full flex flex-col">
      <div :if={@threads == []} class="bg-white border border-gray-200 rounded-card p-12 text-center">
        <p class="text-lg font-semibold text-gray-900">No conversations yet</p>
        <p class="text-sm text-gray-500 mt-2">
          Open one from a merchant's page when you need to reach them.
        </p>
      </div>

      <div
        :if={@threads != []}
        class="flex-1 min-h-0 grid grid-cols-1 lg:grid-cols-[330px_minmax(0,1fr)] bg-white rounded-card overflow-hidden shadow-lg shadow-slate-900/5 ring-1 ring-slate-200/60 lg:h-[calc(100vh-9.5rem)] lg:min-h-[480px]"
      >
        <%!-- Chats pane --%>
        <div class="flex flex-col border-b lg:border-b-0 lg:border-r border-slate-100 min-h-0">
          <div class="flex items-center gap-3 px-4 py-3.5 border-b border-slate-100 shrink-0">
            <.initials_avatar
              name={staff_name(@current_user)}
              tint="bg-gradient-to-br from-blue-400 to-blue-600 text-white"
            />
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
                %{thread: thread, last: last, unread: unread} <- visible_threads(@threads, @query)
              }
              navigate={~p"/platform/messages/#{thread.id}"}
              class={[
                "flex items-center gap-3 rounded-xl px-3 py-2.5 transition-colors",
                if(@thread && @thread.id == thread.id,
                  do:
                    "bg-gradient-to-br from-emerald-600 to-emerald-700 shadow-lg shadow-emerald-600/30",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <.initials_avatar name={merchant_name(thread)} size="size-9.5" text="text-xs" />
              <div class="min-w-0 flex-1">
                <div class="flex items-baseline justify-between gap-2">
                  <p class={[
                    "truncate text-[13.5px] font-semibold",
                    if(@thread && @thread.id == thread.id, do: "text-white", else: "text-slate-900")
                  ]}>
                    {merchant_name(thread)}
                  </p>
                  <span class={[
                    "shrink-0 text-[10.5px]",
                    if(@thread && @thread.id == thread.id,
                      do: "text-white/75",
                      else: "text-slate-400"
                    )
                  ]}>
                    {EmakolaWeb.LayoutHelpers.relative_time(last && last.inserted_at)}
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
                    {(last && last.body) || "No messages yet"}
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
            <.initials_avatar name={merchant_name(@thread)} />
            <div class="min-w-0 flex-1">
              <p class="text-sm font-bold text-slate-900 truncate">{merchant_name(@thread)}</p>
              <p class="text-[11.5px] text-slate-400 truncate">{merchant_email(@thread)}</p>
            </div>
            <.link
              navigate={~p"/platform/merchants"}
              class="flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3.5 py-2 text-xs font-semibold text-slate-600 transition-colors hover:border-slate-300"
            >
              View merchant <.icon name="hero-arrow-up-right" class="size-3" />
            </.link>
          </div>

          <div id="messages" class="flex-1 min-h-0 px-5 py-5 space-y-4 overflow-y-auto">
            <.chat_group
              :for={group <- group_messages(@messages)}
              group={group}
              own?={group.author_kind == :platform}
              read_at={@thread.merchant_last_read_at}
            >
              <:avatar>
                <.initials_avatar
                  :if={group.author_kind == :platform}
                  name={staff_name(@current_user)}
                  size="size-8"
                  text="text-[11px]"
                  tint="bg-gradient-to-br from-blue-400 to-blue-600 text-white"
                />
                <.initials_avatar
                  :if={group.author_kind != :platform}
                  name={merchant_name(@thread)}
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
          <p class="text-sm text-slate-500">Pick a conversation to read it.</p>
        </div>
      </div>
    </div>
    """
  end

  defp visible_threads(threads, ""), do: threads

  defp visible_threads(threads, query) do
    needle = String.downcase(query)

    Enum.filter(threads, fn %{thread: thread} ->
      String.contains?(String.downcase(merchant_name(thread)), needle)
    end)
  end

  # Staff accounts carry only an email; the local part is the display name.
  defp staff_name(user) do
    user.email |> to_string() |> String.split("@") |> hd()
  end

  defp merchant_email(%{merchant: %{email: email}}) when not is_nil(email), do: to_string(email)
  defp merchant_email(_thread), do: ""

  defp merchant_name(%{merchant: %{name: name}}) when is_binary(name) and name != "", do: name

  defp merchant_name(%{merchant: %{email: email}}) when not is_nil(email),
    do: to_string(email)

  defp merchant_name(_thread), do: "Merchant"
end
