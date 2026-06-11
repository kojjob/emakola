defmodule EmakolaWeb.Platform.AuditLogLive do
  @moduledoc """
  Read-only platform audit log feed, gated by :view_audit_log.

  Entries are streamed (the log grows unbounded — streams keep LiveView
  memory flat) and keyset-paginated 50 at a time via the resource's :list
  action. Actor emails are resolved with one batched query per page,
  accumulated into an assigns map so already-resolved ids are never
  re-queried. The page is read-only, but load_more still re-checks the
  permission against a freshly reloaded user for symmetry with the other
  platform pages — mount-time auth is never trusted.
  """
  use EmakolaWeb, :live_view

  on_mount({EmakolaWeb.Hooks.RequirePermission, :view_audit_log})

  import EmakolaWeb.Platform.AuditLogComponents

  require Ash.Query

  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.User

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Audit log")
      |> assign(:active_nav, :audit_log)
      |> assign(:actors, %{})
      |> assign(:cursor, nil)
      |> assign(:end_of_timeline?, false)
      |> assign(:loaded?, false)
      |> stream(:entries, [])

    # No DB queries in disconnected mount — render a loading shell first.
    socket = if connected?(socket), do: load_page(socket), else: socket

    {:ok, socket}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    # Assigns are stale — re-check the permission against a reloaded user.
    if PlatformPermissions.allowed?(reload_current_user(socket), :view_audit_log) do
      {:noreply, load_page(socket)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to view the audit log.")}
    end
  end

  defp load_page(socket) do
    page_opts =
      case socket.assigns.cursor do
        nil -> [limit: @page_size]
        cursor -> [limit: @page_size, after: cursor]
      end

    case Emakola.Accounts.list_platform_audit_logs(page: page_opts, authorize?: false) do
      {:ok, %Ash.Page.Keyset{results: entries, more?: more?}} ->
        socket
        |> stream(:entries, entries)
        |> assign(:loaded?, true)
        |> assign(:cursor, next_cursor(entries, socket.assigns.cursor))
        |> assign(:end_of_timeline?, !more?)
        |> assign(:actors, resolve_actors(socket.assigns.actors, entries))

      {:error, _reason} ->
        socket
        |> assign(:loaded?, true)
        |> put_flash(:error, "Could not load the audit log.")
    end
  end

  defp next_cursor([], cursor), do: cursor
  defp next_cursor(entries, _cursor), do: List.last(entries).__metadata__.keyset

  # One batched query per page; ids already in the map are never re-queried.
  defp resolve_actors(actors, entries) do
    ids =
      entries
      |> Enum.map(& &1.actor_id)
      |> Enum.reject(&(is_nil(&1) or Map.has_key?(actors, &1)))
      |> Enum.uniq()

    case ids do
      [] ->
        actors

      ids ->
        User
        |> Ash.Query.filter(id in ^ids)
        |> Ash.read(authorize?: false)
        |> case do
          {:ok, users} -> Enum.into(users, actors, &{&1.id, to_string(&1.email)})
          {:error, _} -> actors
        end
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.audit_log_page
      loaded?={@loaded?}
      entries={@streams.entries}
      actors={@actors}
      end_of_timeline?={@end_of_timeline?}
    />
    """
  end
end
