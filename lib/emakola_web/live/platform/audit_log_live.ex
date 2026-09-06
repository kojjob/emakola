defmodule EmakolaWeb.Platform.AuditLogLive do
  @moduledoc """
  The platform audit ledger, gated by :view_audit_log.

  Filters live in the URL (`PlatformAuditSearch.from_params/1`), so every
  chip, select and search box push-patches and `handle_params/3` reloads.
  Entries are streamed (the log grows unbounded, streams keep LiveView
  memory flat) and keyset-paginated 50 at a time, with a day band item
  interleaved before the first entry of each day. New entries arrive over
  PubSub and are only counted; the reader chooses when to reload, so the
  list never shifts under them. load_more re-checks the permission against
  a freshly reloaded user, as every platform page does.
  """
  use EmakolaWeb, :live_view

  on_mount({EmakolaWeb.Hooks.RequirePermission, :view_audit_log})

  import EmakolaWeb.Platform.AuditLogComponents

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditSearch, as: Search
  alias Emakola.Accounts.PlatformPermissions

  @page_size 50
  @filter_keys ~w(family severity range q)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Emakola.PubSub, PlatformAudit.topic())

    socket =
      socket
      |> assign(:page_title, "Audit log")
      |> assign(:active_nav, :audit_log)
      |> assign(:search, %Search{})
      |> assign(:counts, %{})
      |> assign(:actors, %{})
      |> assign(:cursor, nil)
      |> assign(:last_date, nil)
      |> assign(:loaded_count, 0)
      |> assign(:new_count, 0)
      |> assign(:end_of_timeline?, false)
      |> assign(:loaded?, false)
      |> stream(:entries, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :search, Search.from_params(params))

    # No DB queries in disconnected mount: render the loading shell first.
    {:noreply, if(connected?(socket), do: reload(socket), else: socket)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    next =
      socket.assigns.search
      |> Search.to_params()
      |> Map.merge(Map.take(params, @filter_keys))
      |> Search.from_params()

    {:noreply, push_patch(socket, to: ~p"/platform/audit-log?#{Search.to_params(next)}")}
  end

  def handle_event("show_new", _params, socket), do: {:noreply, reload(socket)}

  def handle_event("load_more", _params, socket) do
    # Assigns are stale: re-check the permission against a reloaded user.
    # The reload fails closed (nil) on lookup errors, so the message stays
    # neutral; a transient DB error is not a permission denial.
    if PlatformPermissions.allowed?(reload_current_user(socket), :view_audit_log) do
      {:noreply, load_page(socket)}
    else
      {:noreply,
       put_flash(socket, :error, "Could not verify your access. Refresh and try again.")}
    end
  end

  @impl true
  def handle_info({:platform_audit_logged, entry}, socket) do
    if Search.matches?(socket.assigns.search, entry),
      do: {:noreply, update(socket, :new_count, &(&1 + 1))},
      else: {:noreply, socket}
  end

  defp reload(socket) do
    socket
    |> stream(:entries, [], reset: true)
    |> assign(cursor: nil, last_date: nil, loaded_count: 0, new_count: 0)
    |> assign(:end_of_timeline?, false)
    |> assign(:counts, Search.counts(socket.assigns.search))
    |> load_page()
  end

  defp load_page(socket) do
    %{search: search, cursor: cursor, last_date: last_date} = socket.assigns

    case Search.page(search, limit: @page_size, after: cursor) do
      {:ok, %Ash.Page.Keyset{results: entries, more?: more?}} ->
        {items, last_date} = Search.with_bands(entries, last_date)

        socket
        |> stream(:entries, items)
        |> assign(:loaded?, true)
        |> assign(:cursor, next_cursor(entries, cursor))
        |> assign(:last_date, last_date)
        |> assign(:end_of_timeline?, !more?)
        |> update(:loaded_count, &(&1 + length(entries)))
        |> assign(:actors, Search.actor_names(socket.assigns.actors, entries))

      {:error, _reason} ->
        socket
        |> assign(:loaded?, true)
        |> put_flash(:error, "Could not load the audit log.")
    end
  end

  defp next_cursor([], cursor), do: cursor
  defp next_cursor(entries, _cursor), do: List.last(entries).__metadata__.keyset

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
      search={@search}
      counts={@counts}
      loaded_count={@loaded_count}
      new_count={@new_count}
    />
    """
  end
end
