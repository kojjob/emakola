defmodule EmakolaWeb.Platform.AuditLogComponents do
  @moduledoc """
  Function components for the platform audit log page: streamed entry
  table with severity-tinted action badges, actor labels, and metadata
  chips. Extracted from AuditLogLive to keep that module small.
  """
  use Phoenix.Component

  @red_actions [
    :sign_in_failed,
    :totp_failed,
    :sessions_force_revoked,
    :staff_deactivated,
    :store_blocked,
    :store_archived
  ]
  @amber_actions [:session_revoked, :invite_revoked, :totp_disabled, :store_suspended]
  @green_actions [
    :sign_in_succeeded,
    :invite_accepted,
    :totp_enabled,
    :staff_reactivated,
    :store_reactivated
  ]

  attr :loaded?, :boolean, required: true
  attr :entries, :any, required: true
  attr :actors, :map, required: true
  attr :end_of_timeline?, :boolean, required: true

  def audit_log_page(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Audit log</h1>
        <p class="text-sm text-gray-500 mt-1">Security events for platform staff</p>
      </div>

      <p :if={!@loaded?} class="text-sm text-gray-500">Loading audit log…</p>

      <div :if={@loaded?} class="bg-white rounded-xl border border-gray-200 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 text-left text-xs uppercase tracking-wide text-gray-400">
              <th class="px-4 py-3 font-medium">Time (UTC)</th>
              <th class="px-4 py-3 font-medium">Action</th>
              <th class="px-4 py-3 font-medium">Actor</th>
              <th class="px-4 py-3 font-medium">IP</th>
              <th class="px-4 py-3 font-medium">Details</th>
            </tr>
          </thead>
          <tbody id="audit-entries" phx-update="stream" class="divide-y divide-gray-50">
            <tr :for={{dom_id, entry} <- @entries} id={dom_id} class="align-top">
              <td class="px-4 py-3 font-mono text-xs text-gray-500 whitespace-nowrap">
                {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M:%S")}
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <span class={[
                  "inline-block rounded-full border px-2.5 py-0.5 text-xs font-medium",
                  severity_class(entry.action)
                ]}>
                  {action_label(entry.action)}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-700">{actor_label(entry.actor_id, @actors)}</td>
              <td class="px-4 py-3 font-mono text-xs text-gray-500">{entry.ip || "—"}</td>
              <td class="px-4 py-3">
                <span
                  :for={{key, value} <- entry.metadata}
                  class="mr-1 mb-1 inline-block rounded-md bg-gray-50 border border-gray-200 px-2 py-0.5 text-xs text-gray-600"
                >
                  {key}: {chip_value(value)}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@loaded? && !@end_of_timeline?} class="mt-4 text-center">
        <button
          id="load-more"
          phx-click="load_more"
          class="rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors cursor-pointer"
        >
          Load more
        </button>
      </div>
    </div>
    """
  end

  defp severity_class(action) when action in @red_actions,
    do: "bg-red-50 text-red-700 border-red-200"

  defp severity_class(action) when action in @amber_actions,
    do: "bg-amber-50 text-amber-700 border-amber-200"

  defp severity_class(action) when action in @green_actions,
    do: "bg-green-50 text-green-700 border-green-200"

  defp severity_class(_action), do: "bg-gray-50 text-gray-600 border-gray-200"

  defp action_label(action) do
    action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp actor_label(nil, _actors), do: "system"

  defp actor_label(actor_id, actors) do
    Map.get(actors, actor_id) || String.slice(actor_id, 0, 8) <> "…"
  end

  defp chip_value(value) when is_map(value), do: inspect(value)
  defp chip_value(value) when is_list(value), do: Enum.map_join(value, ", ", &to_string/1)
  defp chip_value(value), do: to_string(value)
end
