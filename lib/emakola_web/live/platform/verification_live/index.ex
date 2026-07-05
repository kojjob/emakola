defmodule EmakolaWeb.Platform.VerificationLive.Index do
  @moduledoc """
  Platform admin queue of store KYC submissions, filterable by status.

  Gated by RequirePermission (:manage_merchants). No DB queries during the
  disconnected render — a nil state renders a loading shell.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  alias Emakola.Stores

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Verifications")
      |> assign(:active_nav, :verifications)
      |> assign(:filter, :pending)
      |> assign(:verifications, nil)

    {:ok, if(connected?(socket), do: load(socket, :pending), else: socket)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filter =
      case status do
        "approved" -> :approved
        "rejected" -> :rejected
        "all" -> nil
        _ -> :pending
      end

    {:noreply, socket |> assign(:filter, filter) |> load(filter)}
  end

  defp load(socket, filter) do
    verifications =
      case Stores.list_verifications_for_review(%{status: filter},
             load: [:store],
             authorize?: false
           ) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, :verifications, verifications)
  rescue
    exception ->
      Logger.error(
        "[platform.verification_live] load loading verifications raised: #{Exception.message(exception)}"
      )

      assign(socket, :verifications, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Verifications</h1>
        <p class="text-sm text-gray-500 mt-1">Merchant KYC submissions awaiting review.</p>
      </div>

      <div class="mb-4 flex gap-2">
        <button
          :for={
            {label, value} <- [
              {"Pending", "pending"},
              {"Approved", "approved"},
              {"Rejected", "rejected"},
              {"All", "all"}
            ]
          }
          type="button"
          phx-click="filter"
          phx-value-status={value}
          class={[
            "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
            if(to_string(@filter) == value or (is_nil(@filter) and value == "all"),
              do: "bg-gray-900 text-white",
              else: "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50"
            )
          ]}
        >
          {label}
        </button>
      </div>

      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Store</th>
              <th class="px-6 py-3">Business</th>
              <th class="px-6 py-3">Status</th>
              <th class="px-6 py-3">Submitted</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr :if={is_nil(@verifications)}>
              <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">Loading…</td>
            </tr>
            <tr :if={@verifications == []}>
              <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                No submissions
              </td>
            </tr>
            <tr :for={v <- @verifications || []} class="hover:bg-gray-50 transition-colors">
              <td class="px-6 py-4 text-sm font-medium text-gray-900">{store_name(v)}</td>
              <td class="px-6 py-4 text-sm text-gray-600">{v.business_name}</td>
              <td class="px-6 py-4">
                <span class={[
                  "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                  status_class(v.status)
                ]}>
                  {status_label(v.status)}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                {v.submitted_at && Calendar.strftime(v.submitted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4 text-right">
                <.link
                  navigate={~p"/platform/verifications/#{v.id}"}
                  class="text-xs text-blue-600 hover:text-blue-700 font-medium"
                >
                  Review
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp store_name(%{store: %{name: name}}), do: name
  defp store_name(_), do: "—"

  defp status_class(:pending), do: "bg-amber-100 text-amber-700"
  defp status_class(:approved), do: "bg-green-100 text-green-700"
  defp status_class(:rejected), do: "bg-red-100 text-red-700"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()
end
