defmodule EmakolaWeb.Platform.OnboardingLive do
  @moduledoc """
  Platform onboarding-health page: an aggregate milestone funnel plus a
  per-store checklist table (least-complete first, with an incomplete-only
  filter). Gated by RequirePermission (:manage_merchants). No DB on
  disconnected mount.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  alias Emakola.Platform.Onboarding

  @labels %{
    products: "Products",
    live: "Storefront live",
    payout: "Payout",
    kyc: "KYC",
    first_order: "First order"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Onboarding")
      |> assign(:active_nav, :onboarding)
      |> assign(:incomplete_only, false)
      |> assign(:overview, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("toggle_incomplete", _params, socket) do
    {:noreply, assign(socket, :incomplete_only, !socket.assigns.incomplete_only)}
  end

  defp load(socket), do: assign(socket, :overview, Onboarding.overview())

  defp visible_stores(stores, true), do: Enum.filter(stores, &(&1.completed < 5))
  defp visible_stores(stores, false), do: stores

  defp pct(_count, 0), do: 0
  defp pct(count, total), do: round(count / total * 100)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :labels, @labels)

    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Onboarding</h1>
        <p class="text-sm text-gray-500 mt-1">
          How far each merchant is through setup, and where activation drops off.
        </p>
      </div>

      <p :if={is_nil(@overview)} class="text-sm text-gray-500">Loading…</p>

      <div :if={@overview}>
        <div class="bg-white rounded-xl border border-gray-200 p-6 mb-8">
          <h2 class="text-sm font-semibold text-gray-700 mb-4">
            Funnel ({@overview.total_stores} stores)
          </h2>
          <div class="space-y-3">
            <div :for={key <- Onboarding.milestones()} class="flex items-center gap-3">
              <div class="w-32 shrink-0 text-sm text-gray-600">{@labels[key]}</div>
              <div class="flex-1 bg-gray-100 rounded-full h-4 overflow-hidden">
                <div
                  class="bg-blue-500 h-4"
                  style={"width: #{pct(@overview.funnel[key], @overview.total_stores)}%"}
                >
                </div>
              </div>
              <div class="w-24 shrink-0 text-right text-sm text-gray-700">
                {@overview.funnel[key]} ({pct(@overview.funnel[key], @overview.total_stores)}%)
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">Merchants</h2>
          <button
            type="button"
            phx-click="toggle_incomplete"
            class={[
              "px-3 py-1.5 rounded-lg text-sm font-medium border",
              if(@incomplete_only,
                do: "bg-gray-900 text-white border-gray-900",
                else: "bg-white text-gray-600 border-gray-200 hover:bg-gray-50"
              )
            ]}
          >
            Incomplete only
          </button>
        </div>

        <div class="bg-white rounded-xl border border-gray-200 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-4 py-3">Store</th>
                <th :for={key <- Onboarding.milestones()} class="px-4 py-3 text-center">
                  {@labels[key]}
                </th>
                <th class="px-4 py-3 text-right">Done</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr
                :for={s <- visible_stores(@overview.stores, @incomplete_only)}
                class="hover:bg-gray-50"
              >
                <td class="px-4 py-3 font-medium text-gray-900">
                  <.link navigate={~p"/platform/stores/#{s.id}"} class="hover:text-blue-600">
                    {s.name}
                  </.link>
                </td>
                <td :for={key <- Onboarding.milestones()} class="px-4 py-3 text-center">
                  <span class={if s.milestones[key], do: "text-green-600", else: "text-gray-300"}>
                    {if s.milestones[key], do: "✓", else: "✗"}
                  </span>
                </td>
                <td class="px-4 py-3 text-right font-medium text-gray-700">{s.completed}/5</td>
              </tr>
              <tr :if={visible_stores(@overview.stores, @incomplete_only) == []}>
                <td colspan="7" class="px-4 py-12 text-center text-gray-400">No stores</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
