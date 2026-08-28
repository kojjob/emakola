defmodule EmakolaWeb.ChatComponents do
  @moduledoc """
  The shared chat surface: staff ↔ merchant and merchant ↔ buyer render the
  same conversation anatomy, so the pieces that make it read as a chat —
  grouped bubbles, one timestamp per group, two-state read ticks — live here.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

  @doc """
  Chunks messages into consecutive same-author groups, so a run of messages
  from one side shares an avatar and a timestamp.
  """
  def group_messages(messages) do
    messages
    |> Enum.chunk_by(& &1.author_kind)
    |> Enum.map(fn [first | _] = chunk -> %{author_kind: first.author_kind, messages: chunk} end)
  end

  @doc """
  Two states only: sent, or read once the other side's read cursor has
  passed the message. There is no delivered state to show honestly.
  """
  def read?(_message, nil), do: false

  def read?(message, %DateTime{} = cursor) do
    DateTime.compare(message.inserted_at, cursor) != :gt
  end

  @doc "9:03 AM today; the date joins once the message is older than that."
  def message_time(%DateTime{} = at) do
    if DateTime.to_date(at) == Date.utc_today() do
      Calendar.strftime(at, "%-I:%M %p")
    else
      Calendar.strftime(at, "%b %-d, %-I:%M %p")
    end
  end

  attr :group, :map, required: true, doc: "one group_messages/1 entry"
  attr :own?, :boolean, required: true, doc: "written by the side looking at the page"
  attr :read_at, :any, default: nil, doc: "the other side's read cursor, for ticks"
  slot :avatar, required: true

  def chat_group(assigns) do
    assigns = assign(assigns, :last, List.last(assigns.group.messages))

    ~H"""
    <div class={["flex gap-2.5 items-start", @own? && "justify-end"]}>
      <div :if={!@own?} class="shrink-0">{render_slot(@avatar)}</div>
      <div class={["flex flex-col gap-1.5 max-w-[72%] lg:max-w-[62%]", @own? && "items-end"]}>
        <div
          :for={{message, index} <- Enum.with_index(@group.messages)}
          id={"message-#{message.id}"}
          class={[
            "px-4 py-2.5 text-sm leading-relaxed break-words",
            if(@own?,
              do: "bg-emerald-600 text-white shadow-md shadow-emerald-600/20",
              else: "bg-white text-slate-700 shadow-sm ring-1 ring-slate-200/60"
            ),
            bubble_shape(@own?, index)
          ]}
        >
          {message.body}
        </div>
        <div class={["flex items-center gap-1.5 text-[10px] text-slate-400", @own? && "pr-0.5"]}>
          <span :if={@own?} id={"read-#{@last.id}"} data-read={to_string(read?(@last, @read_at))}>
            <svg
              :if={read?(@last, @read_at)}
              class="size-3.5 text-emerald-500"
              viewBox="0 0 28 20"
              fill="none"
              stroke="currentColor"
              stroke-width="2.6"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M2 11l5 5L17 6M11 11l5 5L26 6" />
            </svg>
            <svg
              :if={!read?(@last, @read_at)}
              class="size-3.5 text-slate-300"
              viewBox="0 0 24 20"
              fill="none"
              stroke="currentColor"
              stroke-width="2.6"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M4 11l5 5L19 6" />
            </svg>
          </span>
          {message_time(@last.inserted_at)}
        </div>
      </div>
      <div :if={@own?} class="shrink-0">{render_slot(@avatar)}</div>
    </div>
    """
  end

  # The first bubble of a group points at its author with a sharp corner.
  defp bubble_shape(own?, index)
  defp bubble_shape(true, 0), do: "rounded-[14px] rounded-tr-[4px]"
  defp bubble_shape(false, 0), do: "rounded-[14px] rounded-tl-[4px]"
  defp bubble_shape(_own?, _index), do: "rounded-[14px]"

  @avatar_tints [
    "bg-emerald-100 text-emerald-700",
    "bg-amber-100 text-amber-700",
    "bg-indigo-100 text-indigo-700",
    "bg-pink-100 text-pink-700",
    "bg-cyan-100 text-cyan-700",
    "bg-violet-100 text-violet-700"
  ]

  attr :name, :string, required: true
  attr :size, :string, default: "size-10", doc: "Tailwind size class"
  attr :text, :string, default: "text-[13px]"
  attr :tint, :string, default: nil, doc: "bg/text classes; defaults to a hash of the name"
  attr :class, :string, default: nil

  def initials_avatar(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-center rounded-full font-bold shrink-0",
      @size,
      @text,
      @tint || avatar_tint(@name),
      @class
    ]}>
      {initials(@name)}
    </div>
    """
  end

  defp avatar_tint(name) do
    Enum.at(@avatar_tints, :erlang.phash2(name, length(@avatar_tints)))
  end

  defp initials(name) do
    name
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      letters -> letters
    end
  end

  attr :form, :any, required: true
  attr :input_name, :string, default: "message[body]"

  def chat_composer(assigns) do
    ~H"""
    <div class="px-4 pb-4 pt-2 shrink-0">
      <div class="flex items-center gap-2.5 bg-white rounded-xl p-2 pl-4 shadow-md shadow-slate-900/5 ring-1 ring-slate-200/60">
        <input
          type="text"
          name={@input_name}
          value={Phoenix.HTML.Form.input_value(@form, :body)}
          placeholder="Type your message here…"
          autocomplete="off"
          aria-label="Your reply"
          class="flex-1 min-w-0 border-0 bg-transparent p-0 text-sm text-slate-800 placeholder:text-slate-400 focus:ring-0"
        />
        <button
          type="submit"
          class="flex items-center gap-2 rounded-[10px] bg-emerald-600 px-4.5 py-2.5 text-[13px] font-semibold text-white shadow-md shadow-emerald-600/25 transition-colors hover:bg-emerald-700 cursor-pointer"
        >
          Send <.icon name="hero-paper-airplane" class="size-4" />
        </button>
      </div>
    </div>
    """
  end
end
