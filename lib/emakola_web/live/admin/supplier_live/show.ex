defmodule EmakolaWeb.Admin.SupplierLive.Show do
  @moduledoc """
  Supplier detail page — contact-header with tap-to-call/WhatsApp, big metric
  cards (owed / paid so far / payment count) and a simple payout list. Owed
  entries can be marked paid, which reduces the outstanding balance.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Supplier",
        active_nav: :suppliers,
        store: store,
        supplier_id: id,
        supplier: nil,
        ledger_entries: []
      )
      |> load_supplier()
      |> load_ledger()

    {:ok, socket}
  end

  @impl true
  def handle_event("mark_paid", %{"id" => entry_id}, socket) do
    entry = Enum.find(socket.assigns.ledger_entries, &(&1.id == entry_id))

    if entry do
      case Emakola.Suppliers.mark_ledger_entry_paid(entry, authorize?: false) do
        {:ok, _} ->
          {:noreply,
           socket
           |> load_supplier()
           |> load_ledger()
           |> put_flash(:info, "Entry marked paid")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not mark entry paid")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Data loading ──

  defp load_supplier(socket) do
    %{supplier_id: id, store: store} = socket.assigns

    supplier =
      if store do
        case Emakola.Suppliers.get_supplier_by_store(id, store.id, authorize?: false) do
          {:ok, nil} -> nil
          {:ok, s} -> Ash.load!(s, :outstanding_balance, authorize?: false)
          _ -> nil
        end
      end

    assign(socket,
      supplier: supplier,
      page_title: if(supplier, do: supplier.name, else: "Supplier Not Found")
    )
  end

  defp load_ledger(socket) do
    case socket.assigns.supplier do
      nil ->
        assign(socket, ledger_entries: [])

      supplier ->
        entries =
          Emakola.Suppliers.list_ledger_entries_by_supplier!(supplier.id, authorize?: false)

        assign(socket, ledger_entries: entries)
    end
  end

  defp paid_total(entries) do
    entries
    |> Enum.filter(&(&1.status == :paid))
    |> Enum.map(& &1.amount_owed)
    |> Enum.sum()
  end

  defp format_date(nil), do: nil
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y")
  defp format_date(_), do: nil

  defp avatar_color(name) do
    colors = ~w(bg-sky-500 bg-amber-500 bg-violet-500 bg-rose-500
                bg-primary bg-indigo-500 bg-orange-500 bg-teal-500)
    Enum.at(colors, :erlang.phash2(name || "", length(colors)))
  end

  defp initial(name) do
    case name |> to_string() |> String.trim() |> String.first() do
      nil -> "?"
      letter -> String.upcase(letter)
    end
  end

  defp wa_link(number), do: "https://wa.me/" <> String.replace(number, ~r/\D/, "")

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%= if @supplier do %>
        <%!-- Contact header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/admin/settings/suppliers"}
              class="text-slate-400 hover:text-slate-600"
            >
              <.icon name="hero-arrow-left" class="size-5" />
            </.link>
            <img
              :if={@supplier.logo_url}
              src={@supplier.logo_url}
              alt={"#{@supplier.name} logo"}
              class="w-12 h-12 rounded-full object-cover border border-slate-200"
            />
            <div
              :if={!@supplier.logo_url}
              class={[
                "w-12 h-12 rounded-full text-white flex items-center justify-center font-bold text-lg",
                avatar_color(@supplier.name)
              ]}
            >
              {initial(@supplier.name)}
            </div>
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-slate-900">{@supplier.name}</h1>
              <p :if={@supplier.contact_phone} class="text-sm text-slate-400">
                {@supplier.contact_phone}
              </p>
            </div>
          </div>
          <div class="flex gap-2">
            <a
              :if={@supplier.contact_phone}
              href={"tel:#{@supplier.contact_phone}"}
              class="inline-flex items-center gap-2 bg-primary hover:bg-primary-hover text-white
                     font-semibold text-sm rounded-control px-5 py-2.5 transition-colors"
            >
              <.icon name="hero-phone" class="size-4" /> Call
            </a>
            <a
              :if={@supplier.whatsapp_number}
              href={wa_link(@supplier.whatsapp_number)}
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-2 bg-whatsapp hover:opacity-90 text-white
                     font-semibold text-sm rounded-control px-5 py-2.5 transition-colors"
            >
              <.whatsapp_icon class="size-4" /> WhatsApp
            </a>
          </div>
        </div>

        <%!-- Big metric cards --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="bg-red-50 border border-red-200 rounded-card p-6 text-center">
            <p class="text-xs font-bold text-red-800 uppercase tracking-wider">You owe</p>
            <p id="outstanding-balance" class="text-3xl sm:text-4xl font-extrabold text-red-600 mt-2">
              {format_price(@supplier.outstanding_balance || 0, "GHS")}
            </p>
          </div>
          <div class="bg-green-50 border border-green-200 rounded-card p-6 text-center">
            <p class="text-xs font-bold text-green-800 uppercase tracking-wider">Paid so far</p>
            <p class="text-3xl sm:text-4xl font-extrabold text-green-600 mt-2">
              {format_price(paid_total(@ledger_entries), "GHS")}
            </p>
          </div>
          <div class="bg-white border border-slate-200 rounded-card p-6 text-center">
            <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">Payments</p>
            <p class="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-2">
              {length(@ledger_entries)}
            </p>
          </div>
        </div>

        <%!-- Payment details / notes --%>
        <div
          :if={@supplier.payment_details["info"] || @supplier.notes || @supplier.contact_email}
          class="bg-white border border-slate-200 rounded-card p-5 space-y-2"
        >
          <p :if={@supplier.payment_details["info"]} class="text-sm text-slate-700">
            <span class="text-slate-400">Payment:</span> {@supplier.payment_details["info"]}
          </p>
          <p :if={@supplier.contact_email} class="text-sm text-slate-700">
            <span class="text-slate-400">Email:</span> {@supplier.contact_email}
          </p>
          <p :if={@supplier.notes} class="text-sm text-slate-500">
            {@supplier.notes}
          </p>
        </div>

        <%!-- Payout list --%>
        <div class="bg-white border border-slate-200 rounded-card overflow-hidden">
          <div :if={@ledger_entries == []} class="p-12 text-center">
            <.icon name="hero-banknotes" class="size-12 text-slate-300 mx-auto mb-4" />
            <p class="text-sm font-medium text-slate-500">No payments yet</p>
          </div>

          <div :if={@ledger_entries != []} class="divide-y divide-slate-100">
            <div
              :for={entry <- @ledger_entries}
              class="flex items-center justify-between px-5 py-4"
            >
              <div>
                <p class={[
                  "text-lg font-extrabold",
                  if(entry.status == :paid, do: "text-slate-900", else: "text-red-600")
                ]}>
                  {format_price(entry.amount_owed, "GHS")}
                </p>
                <p class="text-xs text-slate-400">
                  <%= if entry.status == :paid do %>
                    Paid {format_date(entry.paid_at) && "on #{format_date(entry.paid_at)}"}
                  <% else %>
                    {format_date(entry.inserted_at)}
                  <% end %>
                </p>
              </div>

              <button
                :if={entry.status == :owed}
                phx-click="mark_paid"
                phx-value-id={entry.id}
                class="inline-flex items-center gap-2 bg-primary hover:bg-primary-hover text-white
                       font-semibold text-sm rounded-control px-5 py-2.5 transition-colors"
              >
                <.icon name="hero-check" class="size-4" /> Mark Paid
              </button>
              <span
                :if={entry.status == :paid}
                class="inline-flex items-center gap-1.5 bg-green-50 text-green-700 font-bold
                       text-sm rounded-full px-3.5 py-1.5"
              >
                <.icon name="hero-check" class="size-3.5" /> Paid
              </span>
            </div>
          </div>
        </div>
      <% else %>
        <div class="flex items-center gap-2">
          <.link navigate={~p"/admin/settings/suppliers"} class="text-slate-400 hover:text-slate-600">
            <.icon name="hero-arrow-left" class="size-4" />
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Supplier Not Found</h1>
        </div>
      <% end %>
    </div>
    """
  end

  attr :class, :string, default: "size-4"

  defp whatsapp_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347Z" />
      <path d="M12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0 0 20.464 3.48 11.815 11.815 0 0 0 12.05 0Zm0 21.785h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26C2.117 6.443 6.552 2.009 12.004 2.009c2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884Z" />
    </svg>
    """
  end
end
