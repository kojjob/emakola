defmodule EmakolaWeb.Admin.Content.MediaLive.Index do
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns[:current_store]

    media =
      if store do
        Emakola.Content.MediaAttachment
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!(authorize?: false)
      else
        []
      end

    {:ok,
     socket
     |> assign(:page_title, "Media Library")
     |> assign(:active_nav, :media)
     |> assign(:media, media)
     |> assign(:filter_type, :all)}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    filter = Emakola.SafeAtom.to_atom_in(type, [:all, :image, :video, :audio], :all)
    {:noreply, assign(socket, :filter_type, filter)}
  end

  @impl true
  def render(assigns) do
    filtered =
      case assigns.filter_type do
        :all -> assigns.media
        type -> Enum.filter(assigns.media, &(&1.type == type))
      end

    assigns = assign(assigns, :filtered_media, filtered)

    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        title="Media Library"
        subtitle={"#{length(@media)} #{if length(@media) == 1, do: "file", else: "files"}"}
      />

      <%!-- Filters --%>
      <div class="flex gap-2">
        <button
          :for={type <- [:all, :image, :video, :audio]}
          phx-click="filter_type"
          phx-value-type={type}
          class={"px-3 py-1.5 rounded-lg text-sm font-medium transition-colors cursor-pointer #{if @filter_type == type, do: "bg-emerald-600 text-white shadow-sm", else: "bg-white text-slate-600 hover:bg-slate-50 shadow-sm"}"}
        >
          {type_label(type)}
        </button>
      </div>

      <%!-- Media Grid --%>
      <div :if={@filtered_media != []} class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <div
          :for={item <- @filtered_media}
          class="bg-white rounded-2xl shadow-sm hover:shadow-md transition-shadow overflow-hidden group"
        >
          <div class="aspect-square bg-slate-100 flex items-center justify-center">
            <img
              :if={item.type == :image}
              src={item.url}
              alt={item.alt_text || item.filename}
              class="w-full h-full object-cover"
              loading="lazy"
            />
            <div :if={item.type == :video} class="text-center p-4">
              <svg
                class="w-10 h-10 text-slate-400 mx-auto mb-2"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="m15.75 10.5 4.72-4.72a.75.75 0 0 1 1.28.53v11.38a.75.75 0 0 1-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 0 0 2.25-2.25v-9a2.25 2.25 0 0 0-2.25-2.25h-9A2.25 2.25 0 0 0 2.25 7.5v9a2.25 2.25 0 0 0 2.25 2.25Z"
                />
              </svg>
              <p class="text-xs text-slate-500 truncate">{item.filename}</p>
            </div>
            <div :if={item.type == :audio} class="text-center p-4">
              <svg
                class="w-10 h-10 text-slate-400 mx-auto mb-2"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.114 5.636a9 9 0 0 1 0 12.728M16.463 8.288a5.25 5.25 0 0 1 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
                />
              </svg>
              <p class="text-xs text-slate-500 truncate">{item.filename}</p>
            </div>
          </div>
          <div class="p-3">
            <p class="text-sm font-medium text-slate-900 truncate">{item.filename || "Untitled"}</p>
            <p class="text-xs text-slate-400 mt-0.5">
              {String.capitalize(to_string(item.type))}
              {if item.file_size, do: " -- #{format_size(item.file_size)}", else: ""}
            </p>
          </div>
        </div>
      </div>

      <div
        :if={@filtered_media == []}
        class="bg-white rounded-2xl shadow-sm p-12 text-center"
      >
        <svg
          class="w-12 h-12 text-slate-300 mx-auto mb-3"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
          />
        </svg>
        <p class="text-sm text-slate-500">No media files yet.</p>
        <p class="text-xs text-slate-400 mt-1">
          Upload images, videos, and audio when creating posts.
        </p>
      </div>
    </div>
    """
  end

  defp type_label(:all), do: "All"
  defp type_label(:image), do: "Images"
  defp type_label(:video), do: "Videos"
  defp type_label(:audio), do: "Audio"

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
