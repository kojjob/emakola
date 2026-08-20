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

  defp load(socket) do
    overview = Onboarding.overview()

    socket
    |> assign(:overview, overview)
    |> assign(:fully_set_up_count, Enum.count(overview.stores, &(&1.completed == 5)))
  end

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
        <%!-- Hero stat tiles --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_tile
            id="onboarding-total-stores"
            label="Total stores"
            value={@overview.total_stores}
            icon="storefront"
            color="blue"
          />
          <.stat_tile
            id="onboarding-fully-set-up"
            label="Fully set up"
            value={@fully_set_up_count}
            icon="check_circle"
            color="green"
          />
          <.stat_tile
            id="onboarding-first-orders"
            label="First orders"
            value={@overview.funnel[:first_order]}
            icon="shopping_bag"
            color="emerald"
          />
          <.stat_tile
            id="onboarding-kyc-approved"
            label="KYC approved"
            value={@overview.funnel[:kyc]}
            icon="verified"
            color="violet"
          />
        </div>

        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 mb-6">
          <h2 class="text-[15px] font-bold text-gray-900 mb-4">
            {"Activation funnel · #{@overview.total_stores} stores"}
          </h2>
          <div class="space-y-3">
            <div :for={key <- Onboarding.milestones()} class="flex items-center gap-3">
              <div class="w-32 shrink-0 text-sm text-gray-600">{@labels[key]}</div>
              <div class="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
                <div
                  class="h-3 rounded-full bg-gradient-to-r from-blue-400 to-blue-600"
                  style={"width: #{pct(@overview.funnel[key], @overview.total_stores)}%"}
                >
                </div>
              </div>
              <div class="w-24 shrink-0 text-right text-sm font-semibold text-gray-700 tabular-nums">
                {"#{@overview.funnel[key]} (#{pct(@overview.funnel[key], @overview.total_stores)}%)"}
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between mb-3">
          <h2 class="text-[15px] font-bold text-gray-900">Merchants</h2>
          <button
            type="button"
            phx-click="toggle_incomplete"
            class={[
              "px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors",
              if(@incomplete_only,
                do: "bg-gray-900 text-white border-gray-900",
                else: "bg-white text-gray-600 border-gray-200 hover:bg-gray-50"
              )
            ]}
          >
            Incomplete only
          </button>
        </div>

        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-x-auto">
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
                :for={store_row <- visible_stores(@overview.stores, @incomplete_only)}
                class="hover:bg-slate-50 transition-colors"
              >
                <td class="px-4 py-3">
                  <.link
                    navigate={~p"/platform/stores/#{store_row.id}"}
                    class="flex items-center gap-3 group"
                  >
                    <.store_avatar store={store_row} class="w-8 h-8 rounded-[9px] text-[13px]" />
                    <span class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors">
                      {store_row.name}
                    </span>
                  </.link>
                </td>
                <td
                  :for={key <- Onboarding.milestones()}
                  data-milestone={key}
                  data-done={store_row.milestones[key]}
                  class="px-4 py-3 text-center"
                >
                  <.icon
                    :if={store_row.milestones[key]}
                    name="hero-check-circle"
                    class="w-5 h-5 text-emerald-500"
                  />
                  <span :if={!store_row.milestones[key]} class="text-gray-300">—</span>
                </td>
                <td class="px-4 py-3 text-right">
                  <.severity_pill
                    label={"#{store_row.completed}/5"}
                    tone={if store_row.completed == 5, do: "green", else: "slate"}
                  />
                </td>
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
