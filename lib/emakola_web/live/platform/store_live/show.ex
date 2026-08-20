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
      |> assign(:action_form, to_form(%{"reason" => ""}))
      |> assign(:store, nil)
      |> assign(:owner, nil)
      |> assign(:history, [])
      |> assign(:history_actors, %{})
      |> assign(:not_found, false)

    {:ok, if(connected?(socket), do: load_store(socket, id), else: socket)}
  end

  @impl true
  def handle_event("open_action_modal", %{"action" => action}, socket) when action in @actions do
    {:noreply, assign(socket, action_modal: action, action_form: to_form(%{"reason" => ""}))}
  end

  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, action_modal: nil, action_form: to_form(%{"reason" => ""}))}
  end

  def handle_event("confirm_action", %{"reason" => reason} = params, socket) do
    socket = assign(socket, :action_form, to_form(params))

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
     |> assign(:action_form, to_form(%{"reason" => ""}))
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
    <div class="p-6 lg:p-8 max-w-6xl mx-auto">
      <.link
        navigate={~p"/platform/stores"}
        class="inline-flex items-center gap-1 text-sm font-medium text-gray-500 hover:text-gray-700 transition-colors"
      >
        <.icon name="hero-chevron-left" class="size-4" /> Back to stores
      </.link>

      <div :if={@not_found} class="mt-6">
        <.platform_empty_state
          icon="hero-building-storefront"
          title="Store not found."
          description="It may have been removed, or the link is stale."
        />
      </div>

      <div
        :if={is_nil(@store) and not @not_found}
        class="mt-6 rounded-2xl border border-gray-200 bg-white p-12 text-center text-sm text-gray-400"
      >
        Loading store…
      </div>

      <div :if={@store} class="mt-5">
        <%!-- Identity header --%>
        <div class="flex flex-wrap items-center gap-4">
          <.store_avatar store={@store} />
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 flex-wrap">
              <h1 class="text-2xl font-bold text-gray-900 tracking-tight truncate">{@store.name}</h1>
              <span id="store-status">
                <.severity_pill
                  label={status_label(@store.status)}
                  tone={status_tone(@store.status)}
                />
              </span>
            </div>
            <p class="text-[13px] text-gray-500 mt-0.5 truncate">
              <span class="font-mono">{@store.slug}</span> {"· #{Map.get(@store, :currency) || "GHS"} · Since #{Calendar.strftime(@store.inserted_at, "%b %d, %Y")}"}
            </p>
          </div>
          <a
            href={"/s/#{@store.slug}"}
            target="_blank"
            class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-blue-600 bg-white ring-1 ring-inset ring-gray-200 hover:bg-slate-50 transition-colors shrink-0"
          >
            View storefront <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
          </a>
        </div>

        <%!-- Current status reason --%>
        <div
          :if={@store.status != :active and @store.status_reason}
          class={[
            "flex items-start gap-2.5 mt-5 px-3.5 py-3 rounded-[10px] ring-1 ring-inset",
            reason_banner_class(@store.status)
          ]}
        >
          <.icon name="hero-exclamation-triangle" class="size-4 shrink-0 mt-0.5" />
          <div class="min-w-0">
            <p class="text-[13px] font-semibold">{status_label(@store.status)} reason</p>
            <p class="text-[13px] leading-relaxed">{@store.status_reason}</p>
            <p :if={@store.status_changed_at} class="mt-0.5 text-[11px] opacity-70">
              Changed {Calendar.strftime(@store.status_changed_at, "%b %d, %Y at %H:%M UTC")}
            </p>
          </div>
        </div>

        <%!-- Detail cards --%>
        <div class="mt-6 grid gap-4 sm:grid-cols-3">
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-gray-500">Owner</span>
              <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-indigo-100 text-indigo-600">
                <.icon name="hero-user" class="size-5" />
              </span>
            </div>
            <p class="mt-3 text-sm font-semibold text-gray-900 truncate">
              {(@owner && (Map.get(@owner, :name) || Map.get(@owner, :email))) || "—"}
            </p>
            <p :if={@owner && Map.get(@owner, :email)} class="text-xs text-gray-500 truncate">
              {@owner.email}
            </p>
          </div>
          <.stat_tile
            label="Products"
            value={Map.get(@store, :product_count) || 0}
            icon="inventory_2"
            color="violet"
          />
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-gray-500">Created</span>
              <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-100 text-emerald-600">
                <.icon name="hero-calendar" class="size-5" />
              </span>
            </div>
            <p class="mt-3 text-sm font-semibold text-gray-900">
              {Calendar.strftime(@store.inserted_at, "%b %d, %Y")}
            </p>
            <p class="text-xs text-gray-500">{Map.get(@store, :currency, "GHS")}</p>
          </div>
        </div>

        <%!-- Lifecycle actions --%>
        <div class="mt-6 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider">Lifecycle</p>
          <p class="text-xs text-gray-400 mt-0.5">
            Actions notify the merchant and are recorded in the audit log.
          </p>
          <div class="mt-3 flex items-center gap-2 flex-wrap">
            <button
              :if={@store.status == :active}
              type="button"
              phx-click="open_action_modal"
              phx-value-action="suspend"
              class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold bg-amber-50 text-amber-700 ring-1 ring-inset ring-amber-600/20 hover:bg-amber-100 transition-colors"
            >
              <.icon name="hero-pause-circle" class="size-4" /> Suspend
            </button>
            <button
              :if={@store.status in [:active, :suspended]}
              type="button"
              phx-click="open_action_modal"
              phx-value-action="block"
              class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold bg-rose-50 text-rose-700 ring-1 ring-inset ring-rose-600/20 hover:bg-rose-100 transition-colors"
            >
              <.icon name="hero-no-symbol" class="size-4" /> Block
            </button>
            <button
              :if={@store.status != :active}
              type="button"
              phx-click="reactivate"
              class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20 hover:bg-green-100 transition-colors"
            >
              <.icon name="hero-arrow-path" class="size-4" /> Reactivate
            </button>
            <button
              :if={@store.status != :archived}
              type="button"
              phx-click="open_action_modal"
              phx-value-action="archive"
              class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold bg-slate-100 text-slate-600 ring-1 ring-inset ring-slate-500/20 hover:bg-slate-200 transition-colors"
            >
              <.icon name="hero-archive-box" class="size-4" /> Archive
            </button>
          </div>
        </div>

        <%!-- Lifecycle history --%>
        <div class="mt-6 rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
          <div class="px-5 py-4 border-b border-gray-100">
            <h2 class="text-sm font-semibold text-gray-900">Lifecycle history</h2>
          </div>
          <p :if={@history == []} class="px-5 py-8 text-center text-sm text-gray-400">
            No lifecycle events yet.
          </p>
          <div
            :for={entry <- @history}
            class="px-5 py-4 flex items-start gap-3.5 border-b border-gray-100 last:border-b-0"
          >
            <span class={[
              "flex h-9 w-9 items-center justify-center rounded-[10px] shrink-0",
              history_chip_class(entry.action)
            ]}>
              <.icon name={history_icon(entry.action)} class="size-[18px]" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-gray-900">{history_label(entry.action)}</p>
              <p :if={entry.metadata["reason"]} class="text-[13px] text-gray-600">
                {entry.metadata["reason"]}
              </p>
              <p class="text-xs text-gray-400 mt-0.5">
                {Map.get(@history_actors, entry.actor_id, "system")}
              </p>
            </div>
            <p class="text-xs text-gray-400 whitespace-nowrap shrink-0">
              {Calendar.strftime(entry.inserted_at, "%b %d, %Y %H:%M")}
            </p>
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
        <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl" phx-click-away="cancel_modal">
          <div class="flex items-center gap-3">
            <span class={[
              "flex h-10 w-10 items-center justify-center rounded-xl shrink-0",
              modal_chip_class(@action_modal)
            ]}>
              <.icon name={modal_icon(@action_modal)} class="size-5" />
            </span>
            <h3 class="text-lg font-semibold text-gray-900">{modal_title(@action_modal)}</h3>
          </div>
          <p class="mt-3 text-sm text-gray-500">{modal_help(@action_modal)}</p>
          <.form
            for={@action_form}
            id="store-lifecycle-form"
            phx-submit="confirm_action"
            class="mt-4"
          >
            <label class="block text-sm font-medium text-gray-700">
              Reason {if reason_required?(@action_modal), do: "(required)", else: "(optional)"}
            </label>
            <.input
              field={@action_form[:reason]}
              type="textarea"
              id="store-lifecycle-reason"
              rows="3"
              class="mt-1 w-full rounded-[10px] border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
              placeholder="Visible to the merchant"
            />
            <div class="mt-4 flex justify-end gap-2">
              <button
                type="button"
                phx-click="cancel_modal"
                class="px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-gray-600 hover:bg-gray-100 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-3.5 py-2 rounded-[10px] text-[13px] font-semibold bg-slate-900 text-white hover:bg-slate-800 transition-colors"
              >
                Confirm
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp reason_required?(action), do: action in @reason_required

  defp status_tone(:active), do: "green"
  defp status_tone(:suspended), do: "amber"
  defp status_tone(:blocked), do: "red"
  defp status_tone(:archived), do: "slate"
  defp status_tone(_), do: "slate"

  defp reason_banner_class(:blocked), do: "bg-rose-50 text-rose-800 ring-rose-200"
  defp reason_banner_class(:archived), do: "bg-slate-50 text-slate-700 ring-slate-200"
  defp reason_banner_class(_), do: "bg-amber-50 text-amber-800 ring-amber-200"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp history_label(action),
    do: action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp history_icon(:store_suspended), do: "hero-pause-circle"
  defp history_icon(:store_blocked), do: "hero-no-symbol"
  defp history_icon(:store_reactivated), do: "hero-arrow-path"
  defp history_icon(:store_archived), do: "hero-archive-box"
  defp history_icon(_), do: "hero-pencil-square"

  defp history_chip_class(:store_suspended), do: "bg-amber-100 text-amber-600"
  defp history_chip_class(:store_blocked), do: "bg-rose-100 text-rose-600"
  defp history_chip_class(:store_reactivated), do: "bg-green-100 text-green-700"
  defp history_chip_class(:store_archived), do: "bg-slate-100 text-slate-500"
  defp history_chip_class(_), do: "bg-slate-100 text-slate-500"

  defp modal_icon("suspend"), do: "hero-pause-circle"
  defp modal_icon("block"), do: "hero-no-symbol"
  defp modal_icon("archive"), do: "hero-archive-box"

  defp modal_chip_class("suspend"), do: "bg-amber-100 text-amber-600"
  defp modal_chip_class("block"), do: "bg-rose-100 text-rose-600"
  defp modal_chip_class("archive"), do: "bg-slate-100 text-slate-500"

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
