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
  attr :id_prefix, :string, default: "message", doc: "DOM id prefix for each bubble"
  slot :avatar, required: true

  def chat_group(assigns) do
    assigns = assign(assigns, :last, List.last(assigns.group.messages))

    ~H"""
    <div class={["flex gap-2.5 items-start", @own? && "justify-end"]}>
      <div :if={!@own?} class="shrink-0">{render_slot(@avatar)}</div>
      <div class={["flex flex-col gap-1.5 max-w-[72%] lg:max-w-[62%]", @own? && "items-end"]}>
        <div
          :for={{message, index} <- Enum.with_index(@group.messages)}
          id={"#{@id_prefix}-#{message.id}"}
          class={[
            "px-4 py-2.5 text-sm leading-relaxed break-words",
            if(@own?,
              do: "bg-emerald-600 text-white shadow-md shadow-emerald-600/20",
              else: "bg-white text-slate-700 shadow-sm ring-1 ring-slate-200/60"
            ),
            bubble_shape(@own?, index)
          ]}
        >
          <p :if={message.body not in [nil, ""]}>{message.body}</p>
          <.chat_attachments
            :if={message.attachments not in [nil, []]}
            attachments={message.attachments}
            own?={@own?}
          />
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

  attr :attachments, :list, required: true
  attr :own?, :boolean, required: true

  # One media element per kind — a picture you can open, sound and video you
  # can play in place, anything else a link. Lazy/metadata loading keeps a
  # media-heavy thread usable on mobile data.
  def chat_attachments(assigns) do
    ~H"""
    <div class="mt-1.5 flex flex-col gap-2 first:mt-0">
      <div :for={att <- @attachments}>
        <a
          :if={media_kind(att) == :image}
          href={att["url"]}
          target="_blank"
          rel="noopener"
          class="block"
        >
          <img
            src={att["url"]}
            alt={att["name"] || "Photo"}
            loading="lazy"
            class="max-h-64 w-auto max-w-full rounded-xl"
          />
        </a>
        <audio :if={media_kind(att) == :audio} controls src={att["url"]} class="w-64 max-w-full">
        </audio>
        <video
          :if={media_kind(att) == :video}
          controls
          preload="metadata"
          src={att["url"]}
          class="max-h-64 w-auto max-w-full rounded-xl"
        >
        </video>
        <a
          :if={media_kind(att) == :file}
          href={att["url"]}
          target="_blank"
          rel="noopener"
          class={[
            "inline-flex items-center gap-2 rounded-lg px-3 py-2 text-xs font-semibold underline",
            if(@own?, do: "bg-white/15 text-white", else: "bg-slate-100 text-slate-700")
          ]}
        >
          <.icon name="hero-paper-clip" class="size-3.5" />
          {att["name"] || "Attachment"}
        </a>
      </div>
    </div>
    """
  end

  defp media_error(:too_large), do: "That file is too big — keep it under 25 MB."
  defp media_error(:too_many_files), do: "Up to 4 files per message."
  defp media_error(:not_accepted), do: "Photos, sound, and video only."
  defp media_error(_other), do: "That file did not attach. Try again."

  defp media_kind(%{"content_type" => "image/" <> _}), do: :image
  defp media_kind(%{"content_type" => "audio/" <> _}), do: :audio
  defp media_kind(%{"content_type" => "video/" <> _}), do: :video
  defp media_kind(_attachment), do: :file

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
  attr :media, :any, default: nil, doc: "an UploadConfig; absent = text-only composer"

  def chat_composer(assigns) do
    ~H"""
    <div id="chat-composer" phx-hook=".ChatComposer" class="px-4 pb-4 pt-2 shrink-0">
      <div
        :if={@media && @media.entries != []}
        class="mb-2 flex flex-wrap gap-2"
      >
        <div
          :for={entry <- @media.entries}
          class="flex items-center gap-2 rounded-lg bg-white px-2.5 py-1.5 text-xs font-semibold text-slate-700 ring-1 ring-slate-200/80 shadow-sm"
        >
          <.live_img_preview
            :if={String.starts_with?(entry.client_type, "image/")}
            entry={entry}
            class="h-8 w-8 rounded-md object-cover"
          />
          <.icon
            :if={!String.starts_with?(entry.client_type, "image/")}
            name="hero-paper-clip"
            class="size-3.5 text-slate-400"
          />
          <span class="max-w-[140px] truncate">{entry.client_name}</span>
          <span :if={entry.progress < 100} class="tabular-nums text-slate-400">
            {entry.progress}%
          </span>
          <button
            type="button"
            phx-click="cancel_media"
            phx-value-ref={entry.ref}
            aria-label="Remove attachment"
            class="text-slate-400 transition-colors hover:text-rose-500 cursor-pointer"
          >
            <.icon name="hero-x-mark" class="size-3.5" />
          </button>
        </div>
      </div>
      <p
        :for={err <- (@media && upload_errors(@media)) || []}
        class="mb-2 text-xs font-semibold text-rose-500"
      >
        {media_error(err)}
      </p>

      <div class="flex items-center gap-2.5 bg-white rounded-xl p-2 pl-4 shadow-md shadow-slate-900/5 ring-1 ring-slate-200/60 focus-within:ring-emerald-500/30 transition-shadow">
        <%!-- A div, not a label: an input nested in a label double-activates in
              Chrome and the second activation can swallow the picker dialog.
              The full-size transparent input is also the only shape iOS
              Safari reliably opens. --%>
        <div
          :if={@media}
          class="relative flex size-9 shrink-0 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-slate-50 hover:text-slate-600"
        >
          <.icon name="hero-paper-clip" class="size-5" />
          <.live_file_input
            upload={@media}
            aria-label="Attach a photo, sound, or video"
            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </div>
        <input
          type="text"
          name={@input_name}
          value={Phoenix.HTML.Form.input_value(@form, :body)}
          placeholder="Type your message here…"
          autocomplete="off"
          aria-label="Your reply"
          class="flex-1 min-w-0 border-0 bg-transparent p-0 text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-0"
        />
        <button
          type="submit"
          class="flex items-center gap-2 rounded-[10px] bg-emerald-600 px-4.5 py-2.5 text-[13px] font-semibold text-white shadow-md shadow-emerald-600/25 transition-colors hover:bg-emerald-700 cursor-pointer"
        >
          Send <.icon name="hero-paper-airplane" class="size-4" />
        </button>
      </div>
    </div>

    <%!-- The server never holds the typed text (no phx-change on the body),
          so after a send its re-render carries the same empty value and
          LiveView leaves the box alone. The page pushes composer:clear and
          the hook empties and refocuses the input. --%>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatComposer">
      export default {
        mounted() {
          this.handleEvent("composer:clear", () => {
            const input = this.el.querySelector("input[type='text']")
            if (!input) return
            input.value = ""
            // Next frame: the Send button still owns focus while its click
            // settles, and Chromium keeps it there if we focus synchronously.
            requestAnimationFrame(() => input.focus())
          })
        }
      }
    </script>
    """
  end
end
