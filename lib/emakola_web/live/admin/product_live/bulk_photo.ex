defmodule EmakolaWeb.Admin.ProductLive.BulkPhoto do
  use EmakolaWeb, :live_view

  @max_photos 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:store_id, socket.assigns.current_store.id)
     |> assign(:max_photos, @max_photos)
     |> assign(:cards, %{})
     |> assign(:publishing, false)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: @max_photos,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Add many products</h1>
          <p class="text-sm text-slate-500">
            Pick all your product photos, give each a name and price, then publish.
          </p>
        </div>
        <.link navigate={~p"/admin/products"} class="text-sm text-slate-500 hover:text-slate-900">
          Back to products
        </.link>
      </div>

      <form id="bulk-photo-form" phx-change="validate" phx-submit="publish_all">
        <label
          class="block border-2 border-dashed border-slate-300 rounded-2xl p-8 text-center cursor-pointer hover:border-emerald-400 transition-colors"
          phx-drop-target={@uploads.photos.ref}
        >
          <.icon name="hero-photo" class="size-10 mx-auto text-slate-400 mb-2" />
          <p class="text-sm font-medium text-slate-700">Tap to choose product photos</p>
          <p class="text-xs text-slate-400 mt-1">Up to {@max_photos} photos at once</p>
          <.live_file_input upload={@uploads.photos} class="sr-only" />
        </label>

        <div :for={err <- upload_errors(@uploads.photos)} class="text-sm text-red-600 mt-2">
          {bulk_upload_error(err)}
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
          <div
            :for={entry <- @uploads.photos.entries}
            class={[
              "border rounded-2xl overflow-hidden bg-white",
              card_incomplete?(@cards, entry.ref) && "border-amber-400",
              !card_incomplete?(@cards, entry.ref) && "border-slate-200"
            ]}
          >
            <div class="relative">
              <.live_img_preview entry={entry} class="w-full h-40 object-cover" />
              <button
                type="button"
                phx-click="remove_photo"
                phx-value-ref={entry.ref}
                class="absolute top-2 right-2 w-7 h-7 bg-black/60 text-white rounded-full text-sm"
                aria-label="Remove photo"
              >
                ✕
              </button>
              <div
                :if={entry.progress < 100}
                class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200"
              >
                <div class="h-full bg-emerald-500" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
            <div class="p-3 space-y-2">
              <label class="block">
                <span class="text-[10px] uppercase tracking-wide text-slate-400">Name</span>
                <input
                  type="text"
                  name="card_name"
                  value={card_value(@cards, entry.ref, :name)}
                  phx-blur="set_card"
                  phx-value-ref={entry.ref}
                  phx-value-field="name"
                  placeholder="e.g. Fresh tomatoes"
                  class="block w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-semibold"
                />
              </label>
              <label class="block">
                <span class="text-[10px] uppercase tracking-wide text-slate-400">Price (GHS)</span>
                <input
                  type="text"
                  name="card_price"
                  value={card_value(@cards, entry.ref, :price)}
                  phx-blur="set_card"
                  phx-value-ref={entry.ref}
                  phx-value-field="price"
                  inputmode="decimal"
                  placeholder="e.g. 20"
                  class="block w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-semibold"
                />
              </label>
              <p :for={err <- upload_errors(@uploads.photos, entry)} class="text-xs text-red-600">
                {bulk_upload_error(err)}
              </p>
            </div>
          </div>
        </div>

        <div
          :if={@uploads.photos.entries != []}
          class="sticky bottom-0 mt-6 bg-white/95 backdrop-blur border-t border-slate-200 py-4 flex justify-end"
        >
          <button
            type="submit"
            disabled={@publishing}
            class="px-6 py-3 bg-emerald-600 text-white text-sm font-semibold rounded-xl hover:bg-emerald-700 disabled:opacity-50"
          >
            {if @publishing,
              do: "Publishing…",
              else: "Publish #{length(@uploads.photos.entries)} products"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_card", %{"ref" => ref, "field" => field, "value" => value}, socket) do
    key = Emakola.SafeAtom.to_atom_in(field, [:name, :price], :name)
    card = Map.get(socket.assigns.cards, ref, %{name: "", price: ""})
    cards = Map.put(socket.assigns.cards, ref, Map.put(card, key, value))
    {:noreply, assign(socket, :cards, cards)}
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photos, ref)
     |> update(:cards, &Map.delete(&1, ref))}
  end

  defp card_value(cards, ref, field), do: cards |> Map.get(ref, %{}) |> Map.get(field, "")

  defp card_incomplete?(cards, ref) do
    card = Map.get(cards, ref, %{})
    name = String.trim(Map.get(card, :name, ""))
    price = EmakolaWeb.Admin.ProductLive.Shared.parse_price_input(Map.get(card, :price, ""))
    name == "" or not match?({:ok, _}, price)
  end

  defp bulk_upload_error(:too_large), do: "One photo is too large (max 10 MB)."
  defp bulk_upload_error(:not_accepted), do: "Only image files are accepted (.jpg, .png, .webp)."
  defp bulk_upload_error(:too_many_files), do: "Up to #{@max_photos} photos at a time."
  defp bulk_upload_error(_), do: "There was a problem with a photo."
end
