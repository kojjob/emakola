defmodule EmakolaWeb.Admin.CustomerLive.Components do
  @moduledoc """
  Render fragments shared by the customer list and detail pages, split out
  once each LiveView module grew past a readable length.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [input: 1]
  import EmakolaWeb.AdminComponents, only: [admin_card: 1, admin_button: 1]

  @doc ~S'Initials for the avatar circle: "Ama Serwaa" -> "AS".'
  def customer_initials(nil), do: "?"

  def customer_initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  attr :status, :atom, required: true

  def order_status_badge(assigns) do
    ~H"""
    <span class={"inline-flex items-center text-xs font-semibold px-2.5 py-1 rounded-full #{status_class(@status)}"}>
      {@status |> to_string() |> String.capitalize()}
    </span>
    """
  end

  defp status_class(:pending), do: "text-amber-700 bg-amber-50"
  defp status_class(:confirmed), do: "text-blue-700 bg-blue-50"
  defp status_class(:processing), do: "text-violet-700 bg-violet-50"
  defp status_class(:shipped), do: "text-indigo-700 bg-indigo-50"
  defp status_class(:delivered), do: "text-emerald-700 bg-emerald-50"
  defp status_class(:cancelled), do: "text-red-700 bg-red-50"
  defp status_class(_), do: "text-slate-700 bg-slate-50"

  attr :segment, :atom, required: true
  attr :segment_counts, :map, required: true

  def segment_chips(assigns) do
    ~H"""
    <div id="customer-segments" class="flex flex-wrap gap-2">
      <button
        :for={segment <- Emakola.Customers.Segments.all()}
        type="button"
        phx-click="segment"
        phx-value-segment={segment}
        data-on={@segment == segment || nil}
        class={[
          "px-3 py-1.5 rounded-full text-sm font-semibold border cursor-pointer",
          @segment == segment && "bg-emerald-600 text-white border-emerald-600",
          @segment != segment && "bg-white text-slate-700 border-slate-200 hover:bg-slate-50"
        ]}
      >
        {Emakola.Customers.Segments.label(segment)} {Map.get(@segment_counts, segment, 0)}
      </button>
    </div>
    """
  end

  attr :adding?, :boolean, required: true
  attr :form, Phoenix.HTML.Form, required: true

  def add_customer_form(assigns) do
    ~H"""
    <.admin_card :if={@adding?} class="p-5">
      <.form
        for={@form}
        id="add-customer-form"
        phx-submit="add_customer"
        class="grid grid-cols-1 sm:grid-cols-3 gap-3"
      >
        <.input field={@form[:name]} label="Name" placeholder="Ama Serwaa" />
        <.input field={@form[:phone]} label="Phone" placeholder="024 123 4567" />
        <.input field={@form[:email]} label="Email (optional)" placeholder="ama@example.com" />
        <div class="sm:col-span-3">
          <.admin_button type="submit">Save customer</.admin_button>
        </div>
      </.form>
    </.admin_card>
    """
  end

  attr :address, :any, default: nil
  attr :returns_count, :integer, required: true
  attr :cancelled_count, :integer, required: true
  attr :failed_payments, :integer, required: true

  def delivery_and_problems(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div :if={@address} id="customer-address" class="bg-white rounded-2xl shadow-sm p-5">
        <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
          Delivers to
        </span>
        <p class="text-sm text-slate-800 mt-2">
          {@address.line_1}<span :if={@address.line_2}>, {@address.line_2}</span>
        </p>
        <p class="text-sm text-slate-500">
          {@address.city}<span :if={@address.region}>, {@address.region}</span>
        </p>
        <p :if={@address.landmark} class="text-sm text-slate-500">{@address.landmark}</p>
      </div>
      <div id="customer-problems" class="bg-white rounded-2xl shadow-sm p-5">
        <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
          Problems
        </span>
        <p class="text-sm text-slate-800 mt-2">{Emakola.Plural.count(@returns_count, "return")}</p>
        <p class="text-sm text-slate-800">{@cancelled_count} cancelled</p>
        <p class="text-sm text-slate-800">
          {Emakola.Plural.count(@failed_payments, "failed payment")}
        </p>
      </div>
    </div>
    """
  end

  attr :note_form, Phoenix.HTML.Form, required: true
  attr :notes, :list, required: true

  def notes_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-sm p-6">
      <h2 class="text-base font-bold text-slate-900 mb-4">Notes</h2>
      <.form for={@note_form} id="note-form" phx-submit="add_note" class="flex gap-2">
        <.input field={@note_form[:content]} placeholder="Only you see this" maxlength="2000" />
        <.admin_button type="submit">Add</.admin_button>
      </.form>
      <ul id="notes" class="mt-4 space-y-3">
        <li
          :for={note <- @notes}
          id={"note-#{note.id}"}
          class="flex items-start justify-between gap-3 bg-slate-50 border border-slate-200 rounded-xl p-3"
        >
          <div>
            <p class="text-sm text-slate-800">{note.content}</p>
            <p class="text-xs text-slate-400 mt-1">
              {Calendar.strftime(note.inserted_at, "%d %b %Y")}
            </p>
          </div>
          <button
            type="button"
            phx-click="remove_note"
            phx-value-id={note.id}
            class="text-xs font-semibold text-slate-500 hover:text-red-700 cursor-pointer"
          >
            Remove
          </button>
        </li>
      </ul>
      <p :if={@notes == []} class="text-sm text-slate-400 mt-3">No notes yet.</p>
    </div>
    """
  end
end
