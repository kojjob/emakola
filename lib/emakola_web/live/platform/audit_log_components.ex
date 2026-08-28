defmodule EmakolaWeb.Platform.AuditLogComponents do
  @moduledoc """
  Function components for the platform audit log page: a streamed severity
  timeline — tinted rail dots per action family, shared severity pills,
  actor labels, and metadata chips. Extracted from AuditLogLive to keep
  that module small.
  """
  use Phoenix.Component

  import EmakolaWeb.PlatformComponents, only: [severity_pill: 1]

  @red_actions [
    :sign_in_failed,
    :totp_failed,
    :sessions_force_revoked,
    :staff_deactivated,
    :store_blocked,
    :store_archived,
    :verification_rejected,
    :product_taken_down
  ]
  @amber_actions [
    :directory_store_excluded,
    :directory_slot_overridden,
    :store_unfeatured,
    :store_verified_badge_revoked,
    :session_revoked,
    :invite_revoked,
    :totp_disabled,
    :store_suspended,
    :impersonation_started,
    :announcement_canceled
  ]
  @green_actions [
    :directory_store_readmitted,
    :store_featured,
    :store_verified_badge_granted,
    :sign_in_succeeded,
    :invite_accepted,
    :totp_enabled,
    :staff_reactivated,
    :store_reactivated,
    :verification_approved,
    :impersonation_ended,
    :product_reinstated,
    :announcement_published
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

      <div :if={@loaded?} class="bg-white rounded-2xl border border-gray-200 shadow-sm p-6">
        <ol id="audit-entries" phx-update="stream">
          <li
            :for={{dom_id, entry} <- @entries}
            id={dom_id}
            data-severity={severity_family(entry.action)}
            class="relative flex gap-4 pb-5 last:pb-0"
          >
            <div class="flex flex-col items-center">
              <span class={[
                "mt-1 h-2.5 w-2.5 rounded-full ring-4 ring-white shrink-0",
                rail_dot_class(entry.action)
              ]}>
              </span>
              <span class="w-px flex-1 bg-gray-100"></span>
            </div>
            <div class="min-w-0 flex-1 -mt-0.5">
              <div class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                <.severity_pill
                  label={action_label(entry.action)}
                  tone={severity_tone(entry.action)}
                />
                <span class="text-[13px] font-semibold text-gray-900">
                  {actor_label(entry.actor_id, @actors)}
                </span>
                <span class="font-mono text-[11px] text-gray-400">
                  {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </span>
                <span :if={entry.ip} class="font-mono text-[11px] text-gray-400">
                  {entry.ip}
                </span>
              </div>
              <div :if={entry.metadata != %{}} class="mt-1.5 flex flex-wrap gap-1">
                <span
                  :for={{key, value} <- entry.metadata}
                  class="inline-block rounded-md bg-gray-50 border border-gray-200 px-2 py-0.5 text-xs text-gray-600"
                >
                  {key}: {chip_value(value)}
                </span>
              </div>
            </div>
          </li>
        </ol>
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

  defp severity_family(action) when action in @red_actions, do: "red"
  defp severity_family(action) when action in @amber_actions, do: "amber"
  defp severity_family(action) when action in @green_actions, do: "green"
  defp severity_family(_action), do: "neutral"

  # severity_pill has no "neutral" tone — the neutral family wears slate.
  defp severity_tone(action) do
    case severity_family(action) do
      "neutral" -> "slate"
      family -> family
    end
  end

  defp rail_dot_class(action) do
    case severity_family(action) do
      "red" -> "bg-red-500"
      "amber" -> "bg-amber-500"
      "green" -> "bg-emerald-500"
      "neutral" -> "bg-gray-300"
    end
  end

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
