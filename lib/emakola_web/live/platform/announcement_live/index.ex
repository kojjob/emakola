defmodule EmakolaWeb.Platform.AnnouncementLive.Index do
  @moduledoc """
  Platform broadcast announcements: list all, create (scheduled + multi-channel
  + status-targeted), and cancel. Gated by RequirePermission
  (:manage_announcements). No DB on disconnected mount. Create/cancel run with
  authorize?: false (the resource forbids actor-based writes), re-check the
  permission per event, enqueue the publish worker, and audit.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_announcements}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker

  @channels [:banner, :email, :sms, :whatsapp]
  @channel_atoms %{
    "banner" => :banner,
    "email" => :email,
    "sms" => :sms,
    "whatsapp" => :whatsapp
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Announcements")
      |> assign(:active_nav, :announcements)
      |> assign(:announcements, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("create", %{"announcement" => params}, socket) do
    authorized(socket, fn socket ->
      attrs = %{
        title: String.trim(params["title"] || ""),
        body: String.trim(params["body"] || ""),
        severity:
          Emakola.SafeAtom.to_atom_in(params["severity"], [:info, :warning, :critical], :info),
        channels: parse_channels(params["channels"]),
        audience: Emakola.SafeAtom.to_atom_in(params["audience"], [:all, :active], :all),
        publish_at: parse_datetime(params["publish_at"]) || DateTime.utc_now(),
        expires_at: parse_datetime(params["expires_at"])
      }

      case Notifications.create_announcement(attrs, authorize?: false) do
        {:ok, ann} ->
          AnnouncementPublishWorker.enqueue(ann.id, ann.publish_at)

          PlatformAudit.log(:announcement_published, socket.assigns.current_user, %{
            "announcement_id" => ann.id,
            "title" => ann.title
          })

          {:noreply, socket |> load() |> put_flash(:info, "Announcement scheduled.")}

        {:error, _} ->
          {:noreply,
           put_flash(socket, :error, "Could not create the announcement. Check the fields.")}
      end
    end)
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      with {:ok, ann} <- Notifications.get_announcement(id, authorize?: false),
           {:ok, _} <- Notifications.cancel_announcement(ann, authorize?: false) do
        PlatformAudit.log(:announcement_canceled, socket.assigns.current_user, %{
          "announcement_id" => ann.id,
          "title" => ann.title
        })

        {:noreply, socket |> load() |> put_flash(:info, "Announcement canceled.")}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not cancel.")}
      end
    end)
  end

  defp parse_channels(list) when is_list(list) do
    Enum.flat_map(list, fn c -> if a = @channel_atoms[c], do: [a], else: [] end)
  end

  defp parse_channels(_), do: []

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(str) when is_binary(str) do
    # datetime-local sends "YYYY-MM-DDTHH:MM" — treat as UTC.
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_announcements) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage announcements.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket) do
    announcements =
      case Notifications.list_announcements_for_admin(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, :announcements, announcements)
  end

  defp display_state(%{status: :canceled}), do: "Canceled"
  defp display_state(%{status: :scheduled}), do: "Scheduled"

  defp display_state(%{status: :published, expires_at: exp}) do
    if exp && DateTime.compare(exp, DateTime.utc_now()) == :lt, do: "Expired", else: "Live"
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :all_channels, @channels)

    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Announcements</h1>
        <p class="text-sm text-gray-500 mt-1">
          Broadcast to merchants via banner, email, SMS, WhatsApp.
        </p>
      </div>

      <form
        id="announcement-form"
        phx-submit="create"
        class="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 mb-8 space-y-4"
      >
        <div>
          <label class="block text-sm font-medium text-gray-700">Title</label>
          <input
            name="announcement[title]"
            required
            class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Message</label>
          <textarea
            name="announcement[body]"
            rows="3"
            required
            class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
          ></textarea>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Severity</label>
            <select
              name="announcement[severity]"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
            >
              <option value="info">Info</option>
              <option value="warning">Warning</option>
              <option value="critical">Critical</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Audience</label>
            <select
              name="announcement[audience]"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
            >
              <option value="all">All stores</option>
              <option value="active">Active stores only</option>
            </select>
          </div>
        </div>
        <div>
          <span class="block text-sm font-medium text-gray-700 mb-1">Channels</span>
          <div class="flex flex-wrap gap-4">
            <label
              :for={c <- @all_channels}
              class="inline-flex items-center gap-1.5 text-sm text-gray-700"
            >
              <input type="checkbox" name="announcement[channels][]" value={c} checked={c == :banner} />
              {c |> to_string() |> String.capitalize()}
            </label>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Publish at (UTC)</label>
            <input
              type="datetime-local"
              name="announcement[publish_at]"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Expires at (UTC, optional)</label>
            <input
              type="datetime-local"
              name="announcement[expires_at]"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"
            />
          </div>
        </div>
        <button
          type="submit"
          class="rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
        >
          Schedule announcement
        </button>
      </form>

      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Title</th>
              <th class="px-6 py-3">Audience</th>
              <th class="px-6 py-3">State</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr :if={is_nil(@announcements)}>
              <td colspan="4" class="px-6 py-12 text-center text-gray-400">Loading…</td>
            </tr>
            <tr :if={@announcements == []}>
              <td colspan="4" class="px-6 py-12 text-center text-gray-400">No announcements yet</td>
            </tr>
            <tr :for={a <- @announcements || []} class="hover:bg-gray-50">
              <td class="px-6 py-4 font-medium text-gray-900">{a.title}</td>
              <td class="px-6 py-4 text-gray-600">{a.audience}</td>
              <td class="px-6 py-4 text-gray-600">{display_state(a)}</td>
              <td class="px-6 py-4 text-right">
                <button
                  :if={a.status == :scheduled}
                  type="button"
                  phx-click="cancel"
                  phx-value-id={a.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-red-100 text-red-700 hover:bg-red-200"
                >
                  Cancel
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
