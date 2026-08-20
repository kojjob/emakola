defmodule EmakolaWeb.Platform.RefundsLive do
  @moduledoc """
  Platform refund oversight: total refunded + count, and a cross-store table of
  refunded payments. Gated by RequirePermission (:manage_billing). No DB on
  disconnected mount.

  Disputes/chargebacks are not modeled yet (separate feature) — this surfaces
  refunds, the money source of truth being `Payment` (status :refunded).
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  alias Emakola.Payments
  alias Emakola.Platform.Stats

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Refunds")
      |> assign(:active_nav, :refunds)
      |> assign(:loaded, false)
      |> assign(:total_refunded, 0)
      |> assign(:refund_count, 0)
      |> assign(:refunds_empty?, true)
      |> stream(:refunds, [])

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  defp load(socket) do
    refunds =
      case Payments.list_refunded_payments(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    socket
    |> assign(:loaded, true)
    |> assign(:total_refunded, Stats.total_refunded())
    |> assign(:refund_count, Stats.refund_count())
    |> assign(:refunds_empty?, refunds == [])
    |> stream(:refunds, refunds, reset: true)
  end

  defp money(nil, _currency), do: "—"

  defp money(amount, currency) when is_integer(amount) do
    major = div(amount, 100)
    minor = rem(abs(amount), 100) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{currency || "GHS"} #{major}.#{minor}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 id="platform-refunds-title" class="text-2xl font-bold text-gray-900">Refunds</h1>
        <p class="text-sm text-gray-500 mt-1">
          Refunded payments across all stores. Disputes &amp; chargebacks coming soon.
        </p>
      </div>

      <p :if={!@loaded} class="text-sm text-gray-500">Loading…</p>

      <div :if={@loaded}>
        <div class="flex flex-wrap gap-4 mb-8">
          <.metric_tile
            label="Total refunded"
            value={money(@total_refunded, "GHS")}
            icon="hero-receipt-refund"
            chip="bg-rose-100 text-rose-600"
          />
          <.metric_tile
            label="Refunds"
            value={@refund_count}
            icon="hero-arrow-uturn-left"
            chip="bg-amber-100 text-amber-600"
          />
        </div>

        <div
          :if={@refunds_empty?}
          id="platform-refunds-empty"
          class="rounded-2xl border border-dashed border-gray-200 bg-white p-16 text-center"
        >
          <.icon name="hero-banknotes" class="mx-auto h-12 w-12 text-emerald-400" />
          <p class="mt-4 text-lg font-semibold text-gray-900">No refunds yet</p>
          <p class="mt-1 text-sm text-gray-500">
            Refunded payments will appear here as they happen.
          </p>
        </div>

        <div
          :if={!@refunds_empty?}
          id="platform-refunds-table"
          class="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden"
        >
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] font-semibold text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Store</th>
                <th class="px-6 py-3">Original</th>
                <th class="px-6 py-3">Refunded</th>
                <th class="px-6 py-3">Gateway</th>
                <th class="px-6 py-3 text-right">Date</th>
              </tr>
            </thead>
            <tbody id="platform-refunds" phx-update="stream" class="divide-y divide-gray-100">
              <tr
                :for={{id, p} <- @streams.refunds}
                id={id}
                class="hover:bg-slate-50 transition-colors"
              >
                <td class="px-6 py-3.5">
                  <div class="flex items-center gap-3">
                    <.store_avatar
                      :if={p.store}
                      store={p.store}
                      class="w-8 h-8 rounded-[9px] text-[13px]"
                    />
                    <p class="text-sm font-semibold text-gray-900">{p.store && p.store.name}</p>
                  </div>
                </td>
                <td class="px-6 py-3.5 text-[13px] text-gray-500 tabular-nums">
                  {money(p.amount, p.currency)}
                </td>
                <td class="px-6 py-3.5 text-[13px] font-bold text-rose-600 tabular-nums">
                  {money(p.refunded_amount, p.currency)}
                </td>
                <td class="px-6 py-3.5">
                  <.severity_pill label={gateway_label(p.gateway)} tone={gateway_tone(p.gateway)} />
                </td>
                <td class="px-6 py-3.5 text-right text-[13px] text-gray-500 whitespace-nowrap">
                  {Calendar.strftime(p.inserted_at, "%b %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp gateway_label(gateway), do: gateway |> to_string() |> String.capitalize()

  defp gateway_tone(:paystack), do: "blue"
  defp gateway_tone(:hubtel), do: "green"
  defp gateway_tone(_), do: "slate"

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :chip, :string, required: true

  defp metric_tile(assigns) do
    ~H"""
    <div class="w-full sm:w-[340px] rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-500">{@label}</span>
        <span class={["flex h-9 w-9 items-center justify-center rounded-xl", @chip]}>
          <.icon name={@icon} class="h-5 w-5" />
        </span>
      </div>
      <p class="mt-3 text-2xl font-bold text-gray-900">{@value}</p>
    </div>
    """
  end
end
