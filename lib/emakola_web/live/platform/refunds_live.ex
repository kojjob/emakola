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
      |> assign(:total_refunded, money(0, "GHS"))
      |> assign(:refund_count, 0)
      |> assign(:shown_count, 0)
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
    |> assign(:total_refunded, totals_by_currency(refunds))
    |> assign(:refund_count, Stats.refund_count())
    |> assign(:shown_count, length(refunds))
    |> assign(:refunds_empty?, refunds == [])
    |> stream(:refunds, refunds, reset: true)
  end

  # Refunded money per currency. `Stats.total_refunded/0` sums `refunded_amount`
  # across every payment regardless of currency and the tile labelled the result
  # "GHS" — one NGN refund made the headline both wrong and mislabelled.
  defp totals_by_currency([]), do: money(0, "GHS")

  defp totals_by_currency(refunds) do
    refunds
    |> Enum.group_by(&(&1.currency || "GHS"), &(&1.refunded_amount || 0))
    |> Enum.map(fn {currency, amounts} -> money(Enum.sum(amounts), currency) end)
    |> Enum.sort()
    |> Enum.join(" · ")
  end

  defp money(nil, _currency), do: "—"

  defp money(amount, currency) when is_integer(amount) do
    # Grouped, as every other money surface formats it — an ungrouped
    # "GHS 1240000.00" is unreadable at a glance.
    major = amount |> div(100) |> Emakola.Money.group_thousands()
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
        <%!-- Same tiles as /platform, so the money pages read as one product
              instead of three tile implementations. --%>
        <div class="grid grid-cols-2 gap-4 mb-8">
          <.stat_tile
            id="platform-refunds-total"
            label="Sent back"
            value={@total_refunded}
            icon="undo"
            color="rose"
          />
          <.stat_tile
            id="platform-refunds-count"
            label="Refunds"
            value={@refund_count}
            icon="autorenew"
            color="amber"
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
          class="rounded-card border border-border bg-surface shadow-sm overflow-hidden"
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

          <%!-- The read is capped server-side. Without saying so, the table
                and the Refunds tile simply disagree past the cap and nothing
                explains why. --%>
          <div
            id="platform-refunds-showing"
            class="px-6 py-3.5 border-t border-gray-100 bg-gray-50 text-[13px] text-gray-500"
          >
            Showing <span class="font-semibold text-gray-900">{@shown_count}</span>
            of <span class="font-semibold text-gray-900">{@refund_count}</span>
            {if @refund_count == 1, do: "refund", else: "refunds"}
            <span :if={@shown_count < @refund_count} class="text-gray-400">
              — newest first
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp gateway_label(gateway), do: gateway |> to_string() |> String.capitalize()

  defp gateway_tone(:paystack), do: "blue"
  defp gateway_tone(:hubtel), do: "green"
  defp gateway_tone(_), do: "slate"
end
