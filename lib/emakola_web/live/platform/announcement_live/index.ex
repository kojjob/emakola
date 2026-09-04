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
      |> assign(:announcement_form, announcement_form())
      |> assign(:announcements_count, 0)
      |> assign(:scheduled_count, 0)
      |> assign(:live_count, 0)
      |> assign(:announcements_loaded?, false)
      |> stream(:announcements, [], dom_id: &"announcement-#{&1.id}")

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  # The preview card follows the form as staff type; nothing is saved.
  @impl true
  def handle_event("preview", %{"announcement" => params}, socket) do
    {:noreply, assign(socket, :announcement_form, to_form(params, as: :announcement))}
  end

  def handle_event("create", %{"announcement" => params}, socket) do
    socket = assign(socket, :announcement_form, to_form(params, as: :announcement))

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

  defp announcement_form do
    to_form(
      %{
        "title" => "",
        "body" => "",
        "severity" => "info",
        "channels" => ["banner"],
        "audience" => "all",
        "publish_at" => "",
        "expires_at" => ""
      },
      as: :announcement
    )
  end

  defp channel_selected?(form, channel) do
    channel_name = to_string(channel)
    Enum.any?(List.wrap(form[:channels].value), &(to_string(&1) == channel_name))
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

    socket
    |> assign(:announcements_count, length(announcements))
    |> assign(:scheduled_count, Enum.count(announcements, &(&1.status == :scheduled)))
    |> assign(:live_count, Enum.count(announcements, &(display_state(&1) == "Live")))
    |> assign(:announcements_loaded?, true)
    |> stream(:announcements, announcements, reset: true)
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
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6 flex items-end justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Announcements</h1>
          <p class="text-sm text-gray-500 mt-1">
            Broadcast to merchants via banner, email, SMS, WhatsApp
          </p>
        </div>
        <div :if={@announcements_loaded?} class="flex items-center gap-2">
          <.severity_pill label={"#{@scheduled_count} scheduled"} tone="amber" />
          <.severity_pill label={"#{@live_count} live"} tone="green" />
        </div>
      </div>

      <div class="flex flex-col lg:flex-row gap-5 items-start">
        <%!-- Compose card --%>
        <.form
          for={@announcement_form}
          id="announcement-form"
          phx-change="preview"
          phx-submit="create"
          class="w-full lg:w-[430px] shrink-0 bg-white rounded-2xl border border-gray-200 shadow-sm p-5"
        >
          <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider">
            New announcement
          </p>
          <div class="mt-3">
            <label for="announcement-title" class="block text-[13px] font-medium text-gray-700">
              Title
            </label>
            <.input
              field={@announcement_form[:title]}
              id="announcement-title"
              required
              class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 focus:bg-white"
            />
          </div>
          <div class="mt-3">
            <label for="announcement-body" class="block text-[13px] font-medium text-gray-700">
              Message
            </label>
            <.input
              field={@announcement_form[:body]}
              type="textarea"
              id="announcement-body"
              rows="3"
              required
              class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 focus:bg-white"
            />
          </div>

          <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mt-4">
            Channels
          </p>
          <div class="flex flex-wrap gap-1.5 mt-2">
            <label
              :for={c <- @all_channels}
              class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-[9px] text-[12px] font-medium text-slate-600 bg-slate-50 ring-1 ring-inset ring-slate-200 cursor-pointer hover:bg-slate-100 transition-colors"
            >
              <input
                id={"announcement-channel-#{c}"}
                type="checkbox"
                name="announcement[channels][]"
                value={c}
                checked={channel_selected?(@announcement_form, c)}
                class="rounded border-slate-300 text-blue-600 focus:ring-blue-500/20"
              />
              {c |> to_string() |> String.capitalize()}
            </label>
          </div>

          <div class="grid grid-cols-2 gap-3 mt-4">
            <div>
              <label for="announcement-severity" class="block text-[13px] font-medium text-gray-700">
                Severity
              </label>
              <.input
                field={@announcement_form[:severity]}
                type="select"
                id="announcement-severity"
                options={[{"Info", "info"}, {"Warning", "warning"}, {"Critical", "critical"}]}
                class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px]"
              />
            </div>
            <div>
              <label for="announcement-audience" class="block text-[13px] font-medium text-gray-700">
                Audience
              </label>
              <.input
                field={@announcement_form[:audience]}
                type="select"
                id="announcement-audience"
                options={[{"All stores", "all"}, {"Active stores only", "active"}]}
                class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px]"
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3 mt-3">
            <div>
              <label for="announcement-publish-at" class="block text-[13px] font-medium text-gray-700">
                Publish at (UTC)
              </label>
              <.input
                field={@announcement_form[:publish_at]}
                type="datetime-local"
                id="announcement-publish-at"
                class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px]"
              />
            </div>
            <div>
              <label for="announcement-expires-at" class="block text-[13px] font-medium text-gray-700">
                Expires at (UTC)
              </label>
              <.input
                field={@announcement_form[:expires_at]}
                type="datetime-local"
                id="announcement-expires-at"
                class="mt-1 w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px]"
              />
            </div>
          </div>

          <div class="mt-4 flex items-center justify-between gap-3">
            <p class="text-[11px] text-gray-400">
              Leave publish time blank to send now. Banner shows until it expires.
            </p>
            <button
              type="submit"
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-slate-900 hover:bg-slate-800 transition-colors shrink-0"
            >
              <.icon name="hero-paper-airplane" class="size-3.5" /> Send
            </button>
          </div>
        </.form>

        <div class="flex-1 min-w-0 w-full">
          <%!-- What a merchant will see, as staff type it. --%>
          <div class="mb-5">
            <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
              What merchants see
            </p>
            <div class="bg-slate-50 border border-gray-200 rounded-2xl p-4 sm:p-5">
              <div class="max-w-[420px]">
                <.announcement_banner
                  announcement={preview_announcement(@announcement_form)}
                  preview
                />
              </div>
            </div>
            <p class="text-[12px] text-gray-400 mt-2">
              Updates as you type. A title under eight words reads best.
            </p>
          </div>

          <%!-- Timeline --%>
          <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Recent broadcasts
          </p>
          <div
            id="platform-announcements"
            phx-update="stream"
            data-count={@announcements_count}
            class="flex flex-col gap-3"
          >
            <div
              :if={!@announcements_loaded?}
              id="platform-announcements-loading"
              class="bg-white rounded-[14px] border border-gray-200 px-5 py-10 text-center text-sm text-gray-400"
            >
              Loading…
            </div>
            <div
              :if={@announcements_loaded? && @announcements_count == 0}
              id="platform-announcements-empty"
              class="bg-white rounded-[14px] border border-dashed border-gray-200 px-5 py-10 text-center text-sm text-gray-400"
            >
              No announcements yet
            </div>
            <div
              :for={{id, a} <- @streams.announcements}
              id={id}
              class={[
                "bg-white rounded-[14px] border border-gray-200 shadow-sm px-5 py-4",
                a.status == :canceled && "opacity-70"
              ]}
            >
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2 flex-wrap">
                  <.severity_pill label={state_label(a)} tone={state_tone(a)} />
                  <.severity_pill
                    :if={a.severity == :warning}
                    label="Warning"
                    tone="amber"
                  />
                  <.severity_pill
                    :if={a.severity == :critical}
                    label="Critical"
                    tone="red"
                  />
                </div>
                <button
                  :if={a.status == :scheduled}
                  type="button"
                  phx-click="cancel"
                  phx-value-id={a.id}
                  class="inline-flex px-3 py-1.5 rounded-lg text-[12px] font-semibold text-rose-700 bg-rose-50 ring-1 ring-inset ring-rose-600/20 hover:bg-rose-100 transition-colors"
                >
                  Cancel
                </button>
              </div>
              <p class="text-[13.5px] font-bold text-gray-900 mt-2.5">{a.title}</p>
              <p class="text-[13px] text-gray-600 mt-0.5 line-clamp-2">{a.body}</p>
              <div class="flex items-center gap-2 mt-2.5 flex-wrap">
                <span
                  :for={c <- a.channels}
                  class="text-[11px] font-semibold text-slate-600 bg-slate-100 px-2 py-0.5 rounded-md"
                >
                  {c |> to_string() |> String.capitalize()}
                </span>
                <span class="text-[11px] text-gray-400">{audience_label(a.audience)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp state_label(a) do
    case display_state(a) do
      "Scheduled" -> "Scheduled · #{Calendar.strftime(a.publish_at, "%b %d, %H:%M")}"
      "Live" -> "Live · #{Calendar.strftime(a.publish_at, "%b %d, %H:%M")}"
      other -> other
    end
  end

  defp state_tone(a) do
    case display_state(a) do
      "Scheduled" -> "amber"
      "Live" -> "green"
      _ -> "slate"
    end
  end

  defp audience_label(:active), do: "Active stores only"
  defp audience_label(_), do: "All stores"

  # The card exactly as a merchant will get it, with stand-in words until
  # staff have typed their own.
  defp preview_announcement(form) do
    %{
      id: "preview",
      title: present_or(form[:title].value, "Your title, in a few words"),
      body: present_or(form[:body].value, "Your message, in one line."),
      severity:
        Emakola.SafeAtom.to_atom_in(form[:severity].value, [:info, :warning, :critical], :info)
    }
  end

  defp present_or(value, fallback) when is_binary(value) do
    if String.trim(value) == "", do: fallback, else: value
  end

  defp present_or(_value, fallback), do: fallback
end
