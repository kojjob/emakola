defmodule EmakolaWeb.Platform.StoreLive.Show do
  @moduledoc """
  Platform admin detail page for a single store — the home for lifecycle
  management (suspend / block / archive / reactivate).

  Mount is gated by RequirePermission (:manage_stores). No DB queries run in
  the disconnected render (a loading shell is shown). Every lifecycle action
  re-checks the permission against a freshly reloaded user, then records a
  platform audit entry and enqueues a merchant notification.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  require Ash.Query

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Notifications.Workers.StoreStatusNotificationWorker
  alias Emakola.Stores

  @reason_required ~w(suspend block)
  @actions ~w(suspend block archive)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Store")
      |> assign(:active_nav, :stores)
      |> assign(:store_id, id)
      |> assign(:action_modal, nil)
      |> assign(:store, nil)
      |> assign(:owner, nil)
      |> assign(:history, [])
      |> assign(:history_actors, %{})
      |> assign(:not_found, false)

    {:ok, if(connected?(socket), do: load_store(socket, id), else: socket)}
  end

  @impl true
  def handle_event("open_action_modal", %{"action" => action}, socket) when action in @actions do
    {:noreply, assign(socket, :action_modal, action)}
  end

  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, :action_modal, nil)}
  end

  def handle_event("confirm_action", %{"reason" => reason}, socket) do
    authorized(socket, fn socket ->
      action = socket.assigns.action_modal
      reason = String.trim(reason || "")

      if action in @reason_required and reason == "" do
        {:noreply, put_flash(socket, :error, "A reason is required.")}
      else
        run_lifecycle(socket, action, reason)
      end
    end)
  end

  def handle_event("reactivate", _params, socket) do
    authorized(socket, fn socket ->
      apply_result(socket, Stores.reactivate_store(socket.assigns.store, %{}, authorize?: false),
        event: :store_reactivated,
        reason: nil,
        flash: "Store reactivated."
      )
    end)
  end

  # ── Lifecycle dispatch ──────────────────────────────────────────

  defp run_lifecycle(socket, "suspend", reason) do
    apply_result(
      socket,
      Stores.suspend_store(socket.assigns.store, %{reason: reason}, authorize?: false),
      event: :store_suspended,
      reason: reason,
      flash: "Store suspended."
    )
  end

  defp run_lifecycle(socket, "block", reason) do
    apply_result(
      socket,
      Stores.block_store(socket.assigns.store, %{reason: reason}, authorize?: false),
      event: :store_blocked,
      reason: reason,
      flash: "Store blocked."
    )
  end

  defp run_lifecycle(socket, "archive", reason) do
    reason = if reason == "", do: nil, else: reason

    apply_result(
      socket,
      Stores.archive_store(socket.assigns.store, %{reason: reason}, authorize?: false),
      event: :store_archived,
      reason: reason,
      flash: "Store archived."
    )
  end

  defp apply_result(socket, {:ok, updated}, opts) do
    event = Keyword.fetch!(opts, :event)
    reason = Keyword.get(opts, :reason)

    PlatformAudit.log(event, socket.assigns.current_user, audit_metadata(updated, reason))
    StoreStatusNotificationWorker.enqueue(updated.id, event)

    {:noreply,
     socket
     |> assign(:store, updated)
     |> assign(:action_modal, nil)
     |> load_history(updated.id)
     |> put_flash(:info, Keyword.fetch!(opts, :flash))}
  end

  defp apply_result(socket, {:error, _reason}, _opts) do
    {:noreply, put_flash(socket, :error, "Could not update the store.")}
  end

  defp audit_metadata(store, reason) do
    base = %{"store_id" => store.id, "store_name" => store.name, "store_slug" => store.slug}
    if reason, do: Map.put(base, "reason", reason), else: base
  end

  # ── Permission gating (re-checked against a fresh user) ──────────

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_stores) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage stores.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  # ── Loading ─────────────────────────────────────────────────────

  defp load_store(socket, id) do
    case Stores.get_store(id,
           authorize?: false,
           load: [:product_count, store_memberships: [:merchant]]
         ) do
      {:ok, nil} ->
        assign(socket, not_found: true)

      {:ok, store} ->
        socket
        |> assign(:store, store)
        |> assign(:owner, find_owner(store))
        |> load_history(store.id)

      {:error, _} ->
        assign(socket, not_found: true)
    end
  end

  defp find_owner(store) do
    case Enum.find(store.store_memberships, &(&1.role == :owner)) do
      nil -> nil
      membership -> membership.merchant
    end
  end

  defp load_history(socket, store_id) do
    entries =
      case PlatformAuditLog
           |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
           |> Ash.read(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, history: entries, history_actors: actor_emails(entries))
  rescue
    exception ->
      Logger.error(
        "[platform.store_live] load_history loading lifecycle history raised: #{Exception.message(exception)}"
      )

      assign(socket, history: [], history_actors: %{})
  end

  defp actor_emails(entries) do
    ids = entries |> Enum.map(& &1.actor_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    case ids do
      [] ->
        %{}

      ids ->
        case Emakola.Accounts.User
             |> Ash.Query.filter(id in ^ids)
             |> Ash.read(authorize?: false) do
          {:ok, users} -> Map.new(users, &{&1.id, &1.email})
          _ -> %{}
        end
    end
  end

  # ── Render ──────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <.link navigate={~p"/platform/stores"} class="text-sm text-gray-500 hover:text-gray-700">
        ← Back to stores
      </.link>

      <div :if={@not_found} class="mt-8 rounded-xl border border-gray-200 bg-white p-12 text-center">
        <p class="text-gray-500">Store not found.</p>
      </div>

      <div
        :if={is_nil(@store) and not @not_found}
        class="mt-8 rounded-xl border border-gray-200 bg-white p-12 text-center text-gray-400"
      >
        Loading store…
      </div>

      <div :if={@store} class="mt-4">
        <%!-- Header --%>
        <div class="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <div class="flex items-center gap-3">
              <h1 class="text-2xl font-bold text-gray-900">{@store.name}</h1>
              <span class={[
                "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                status_badge_class(@store.status)
              ]}>
                {status_label(@store.status)}
              </span>
            </div>
            <p class="text-sm text-gray-500 mt-1 font-mono">{@store.slug}</p>
          </div>
          <a
            href={"/s/#{@store.slug}"}
            target="_blank"
            class="inline-flex items-center gap-1 text-sm text-blue-600 hover:text-blue-700 font-medium"
          >
            View storefront <span class="material-symbols-outlined text-sm">open_in_new</span>
          </a>
        </div>

        <%!-- Lifecycle actions --%>
        <div class="mt-5 flex items-center gap-2 flex-wrap">
          <button
            :if={@store.status == :active}
            type="button"
            phx-click="open_action_modal"
            phx-value-action="suspend"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-amber-100 text-amber-800 hover:bg-amber-200 transition-colors"
          >
            Suspend
          </button>
          <button
            :if={@store.status in [:active, :suspended]}
            type="button"
            phx-click="open_action_modal"
            phx-value-action="block"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-red-100 text-red-700 hover:bg-red-200 transition-colors"
          >
            Block
          </button>
          <button
            :if={@store.status != :active}
            type="button"
            phx-click="reactivate"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-green-100 text-green-700 hover:bg-green-200 transition-colors"
          >
            Reactivate
          </button>
          <button
            :if={@store.status != :archived}
            type="button"
            phx-click="open_action_modal"
            phx-value-action="archive"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition-colors"
          >
            Archive
          </button>
        </div>

        <%!-- Current status reason --%>
        <div
          :if={@store.status != :active and @store.status_reason}
          class="mt-4 rounded-lg border border-gray-200 bg-gray-50 p-4"
        >
          <p class="text-xs font-medium uppercase tracking-wide text-gray-500">
            {status_label(@store.status)} reason
          </p>
          <p class="mt-1 text-sm text-gray-800">{@store.status_reason}</p>
          <p :if={@store.status_changed_at} class="mt-1 text-xs text-gray-400">
            Changed {Calendar.strftime(@store.status_changed_at, "%b %d, %Y at %H:%M UTC")}
          </p>
        </div>

        <%!-- Detail cards --%>
        <div class="mt-6 grid gap-4 sm:grid-cols-3">
          <div class="rounded-xl border border-gray-200 bg-white p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-gray-400">Owner</p>
            <p class="mt-1 text-sm font-medium text-gray-900">
              {(@owner && (Map.get(@owner, :name) || Map.get(@owner, :email))) || "—"}
            </p>
            <p :if={@owner && Map.get(@owner, :email)} class="text-xs text-gray-500">
              {@owner.email}
            </p>
          </div>
          <div class="rounded-xl border border-gray-200 bg-white p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-gray-400">Products</p>
            <p class="mt-1 text-lg font-semibold text-gray-900">
              {Map.get(@store, :product_count) || 0}
            </p>
          </div>
          <div class="rounded-xl border border-gray-200 bg-white p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-gray-400">Created</p>
            <p class="mt-1 text-sm font-medium text-gray-900">
              {Calendar.strftime(@store.inserted_at, "%b %d, %Y")}
            </p>
            <p class="text-xs text-gray-500">{Map.get(@store, :currency, "GHS")}</p>
          </div>
        </div>

        <%!-- Lifecycle history --%>
        <div class="mt-8">
          <h2 class="text-sm font-semibold text-gray-900">Lifecycle history</h2>
          <div class="mt-3 rounded-xl border border-gray-200 bg-white divide-y divide-gray-100">
            <p :if={@history == []} class="p-4 text-sm text-gray-400">No lifecycle events yet.</p>
            <div :for={entry <- @history} class="p-4 flex items-start justify-between gap-4">
              <div>
                <p class="text-sm font-medium text-gray-900">{history_label(entry.action)}</p>
                <p :if={entry.metadata["reason"]} class="text-sm text-gray-600">
                  {entry.metadata["reason"]}
                </p>
                <p class="text-xs text-gray-400 mt-0.5">
                  {Map.get(@history_actors, entry.actor_id, "system")}
                </p>
              </div>
              <p class="text-xs text-gray-400 whitespace-nowrap">
                {Calendar.strftime(entry.inserted_at, "%b %d, %Y %H:%M")}
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Action modal --%>
      <div
        :if={@action_modal}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      >
        <%!-- Cancel on click-away only: backdrop clicks dismiss, but clicks inside
             the dialog (textarea, Confirm) must not bubble up and close it. --%>
        <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl" phx-click-away="cancel_modal">
          <h3 class="text-lg font-semibold text-gray-900">{modal_title(@action_modal)}</h3>
          <p class="mt-1 text-sm text-gray-500">{modal_help(@action_modal)}</p>
          <form phx-submit="confirm_action" class="mt-4">
            <label class="block text-sm font-medium text-gray-700">
              Reason {if reason_required?(@action_modal), do: "(required)", else: "(optional)"}
            </label>
            <textarea
              name="reason"
              rows="3"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
              placeholder="Visible to the merchant"
            ></textarea>
            <div class="mt-4 flex justify-end gap-2">
              <button
                type="button"
                phx-click="cancel_modal"
                class="px-3 py-1.5 rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-100"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-3 py-1.5 rounded-lg text-sm font-medium bg-gray-900 text-white hover:bg-gray-800"
              >
                Confirm
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp reason_required?(action), do: action in @reason_required

  defp status_badge_class(:active), do: "bg-green-100 text-green-700"
  defp status_badge_class(:suspended), do: "bg-amber-100 text-amber-700"
  defp status_badge_class(:blocked), do: "bg-red-100 text-red-700"
  defp status_badge_class(:archived), do: "bg-gray-200 text-gray-600"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp history_label(action),
    do: action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp modal_title("suspend"), do: "Suspend store"
  defp modal_title("block"), do: "Block store"
  defp modal_title("archive"), do: "Archive store"

  defp modal_help("suspend"),
    do: "The storefront goes offline and the merchant is locked out until you reactivate it."

  defp modal_help("block"),
    do: "A severe, long-term block. The storefront goes offline until you reactivate it."

  defp modal_help("archive"),
    do: "Removes the store from the platform. Nothing is deleted — you can restore it later."
end
