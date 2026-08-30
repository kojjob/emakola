defmodule EmakolaWeb.Platform.VerificationLive.Index do
  @moduledoc """
  Platform "Verification Studio": KYC review as a split view — the
  submission queue on the left (oldest first, status filters) and a case
  panel on the right with both documents embedded via short-lived
  presigned URLs, an inline decision (reject reason without a modal,
  approve awards the Store.verified badge), and the store's review
  history from the platform audit log.

  Gated by RequirePermission (:manage_merchants). No DB queries during
  the disconnected render. Decisions re-check the permission against a
  freshly reloaded user, are audited, and notify the merchant. The
  detail page at /platform/verifications/:id remains for deep links.
  """
  use EmakolaWeb, :live_view
  require Logger
  require Ash.Query

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Stores

  @verification_actions [:verification_approved, :verification_rejected]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Verifications")
      |> assign(:active_nav, :verifications)
      |> assign(:filter, :pending)
      |> assign(:pending_count, 0)
      |> assign(:approved_count, 0)
      |> assign(:rejected_count, 0)
      |> assign(:total_count, 0)
      |> assign(:verifications_count, 0)
      |> assign(:verifications_loaded?, false)
      |> assign(:selected, nil)
      |> assign(:queue_ids, [])
      |> assign(:business_doc_url, nil)
      |> assign(:reject_form, to_form(%{"reason" => ""}))
      |> assign(:history, [])
      |> assign(:history_actors, %{})
      |> stream(:verifications, [], dom_id: &"verification-#{&1.id}")

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
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

    {:noreply, socket |> assign(:filter, filter) |> load()}
  end

  def handle_event("select_verification", %{"id" => id}, socket) do
    {:noreply, load(socket, select_id: id)}
  end

  def handle_event("approve", _params, socket) do
    authorized(socket, fn socket ->
      case socket.assigns.selected do
        nil ->
          {:noreply, socket}

        verification ->
          decide(
            socket,
            Stores.approve_store_verification(verification, %{}, authorize?: false),
            verification: verification,
            event: :verification_approved,
            verified: true,
            reason: nil,
            flash: "Verification approved."
          )
      end
    end)
  end

  def handle_event("confirm_reject", %{"reason" => reason} = params, socket) do
    socket = assign(socket, :reject_form, to_form(params))

    authorized(socket, fn socket ->
      reason = String.trim(reason || "")
      verification = socket.assigns.selected

      cond do
        is_nil(verification) ->
          {:noreply, socket}

        reason == "" ->
          {:noreply, put_flash(socket, :error, "A reason is required.")}

        true ->
          decide(
            socket,
            Stores.reject_store_verification(verification, %{reason: reason}, authorize?: false),
            verification: verification,
            event: :verification_rejected,
            verified: false,
            reason: reason,
            flash: "Verification rejected."
          )
      end
    end)
  end

  # j/k walk the queue (pushed by the QueueKeys hook, which skips form fields).
  def handle_event("queue_key", %{"key" => key}, socket) when key in ["j", "k"] do
    ids = socket.assigns.queue_ids
    current = socket.assigns.selected && socket.assigns.selected.id
    index = current && Enum.find_index(ids, &(&1 == current))

    if is_nil(index) do
      {:noreply, socket}
    else
      delta = if key == "j", do: 1, else: -1
      target = Enum.at(ids, index |> Kernel.+(delta) |> min(length(ids) - 1) |> max(0))

      if target == current do
        {:noreply, socket}
      else
        {:noreply, load(socket, select_id: target)}
      end
    end
  end

  def handle_event("queue_key", _params, socket), do: {:noreply, socket}

  defp decide(socket, {:ok, _updated}, opts) do
    verification = Keyword.fetch!(opts, :verification)
    store = verification.store
    event = Keyword.fetch!(opts, :event)
    reason = Keyword.get(opts, :reason)

    verified? = Keyword.fetch!(opts, :verified)

    Stores.update_store_directory_meta(
      store,
      %{
        verified: verified?,
        verified_basis: if(verified?, do: :business_review),
        verified_basis_at: if(verified?, do: DateTime.utc_now())
      },
      authorize?: false
    )

    PlatformAudit.log(event, socket.assigns.current_user, audit_metadata(store, reason))
    Emakola.Notifications.Workers.VerificationStatusNotificationWorker.enqueue(store.id, event)

    {:noreply,
     socket
     |> assign(:reject_form, to_form(%{"reason" => ""}))
     |> load(select_id: verification.id)
     |> put_flash(:info, Keyword.fetch!(opts, :flash))}
  end

  defp decide(socket, {:error, _}, _opts) do
    {:noreply, put_flash(socket, :error, "Could not update the submission.")}
  end

  defp audit_metadata(store, reason) do
    base = %{"store_id" => store.id, "store_name" => store.name}
    if reason, do: Map.put(base, "reason", reason), else: base
  end

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_merchants) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to review verifications.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket, opts \\ []) do
    verifications =
      case Stores.list_verifications_for_review(%{status: nil},
             load: [:store],
             authorize?: false
           ) do
        {:ok, list} -> list
        _ -> []
      end

    assign_verifications(socket, verifications, opts)
  rescue
    exception ->
      Logger.error(
        "[platform.verification_live] load loading verifications raised: #{Exception.message(exception)}"
      )

      assign_verifications(socket, [], opts)
  end

  defp assign_verifications(socket, verifications, opts) do
    filtered = apply_filter(verifications, socket.assigns.filter)

    # An explicit select_id (row clicks, j/k, a just-made decision) is looked
    # up in the FULL list — a just-decided submission leaves the pending
    # filter but must stay on screen for the reviewer. Passive reloads
    # (filter switches) stay filter-scoped so the panel follows the filter.
    selected =
      case Keyword.get(opts, :select_id) do
        nil ->
          previous_id = socket.assigns.selected && socket.assigns.selected.id
          Enum.find(filtered, &(&1.id == previous_id)) || List.first(filtered)

        select_id ->
          Enum.find(verifications, &(&1.id == select_id)) || List.first(filtered)
      end

    socket
    |> assign(:queue_ids, Enum.map(filtered, & &1.id))
    |> assign(:pending_count, Enum.count(verifications, &(&1.status == :pending)))
    |> assign(:approved_count, Enum.count(verifications, &(&1.status == :approved)))
    |> assign(:rejected_count, Enum.count(verifications, &(&1.status == :rejected)))
    |> assign(:total_count, length(verifications))
    |> assign(:verifications_count, length(filtered))
    |> assign(:verifications_loaded?, true)
    |> assign(:selected, selected)
    |> assign(:business_doc_url, selected && doc_url(selected.business_doc_key))
    |> assign_history(selected)
    |> stream(:verifications, Enum.map(filtered, &row(&1, selected)), reset: true)
  end

  defp apply_filter(verifications, nil), do: verifications
  defp apply_filter(verifications, status), do: Enum.filter(verifications, &(&1.status == status))

  defp row(verification, selected) do
    %{
      id: verification.id,
      verification: verification,
      selected?: selected != nil && selected.id == verification.id
    }
  end

  defp doc_url(nil), do: nil

  defp doc_url(key) do
    case Emakola.Storage.presigned_url(key, expires_in: 900) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp assign_history(socket, nil), do: assign(socket, history: [], history_actors: %{})

  defp assign_history(socket, verification) do
    entries =
      case PlatformAuditLog
           |> Ash.Query.for_read(:list_for_store, %{store_id: verification.store_id})
           |> Ash.read(authorize?: false) do
        {:ok, list} -> Enum.filter(list, &(&1.action in @verification_actions))
        _ -> []
      end

    assign(socket, history: entries, history_actors: actor_emails(entries))
  rescue
    exception ->
      Logger.error(
        "[platform.verification_live] assign_history raised: #{Exception.message(exception)}"
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

  defp store_name(%{store: %{name: name}}), do: name
  defp store_name(_), do: "—"

  defp status_tone(:pending), do: "amber"
  defp status_tone(:approved), do: "green"
  defp status_tone(:rejected), do: "red"

  defp status_dot(:pending), do: "bg-amber-400"
  defp status_dot(:approved), do: "bg-green-500"
  defp status_dot(:rejected), do: "bg-red-400"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp history_label(:verification_approved), do: "Approved"
  defp history_label(:verification_rejected), do: "Rejected"

  defp history_label(action),
    do: action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp history_chip_class(:verification_approved), do: "bg-green-100 text-green-700"
  defp history_chip_class(_), do: "bg-rose-100 text-rose-600"

  defp history_icon(:verification_approved), do: "hero-check-circle"
  defp history_icon(_), do: "hero-x-mark"

  defp filter_chip_classes(active?) do
    [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11.5px] transition-colors cursor-pointer",
      if(active?,
        do: "bg-slate-900 text-white font-semibold",
        else:
          "bg-slate-50 text-slate-600 font-medium ring-1 ring-inset ring-slate-200 hover:bg-slate-100"
      )
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="verification-studio" phx-hook="QueueKeys" class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6 flex items-end justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Verifications</h1>
          <p class="text-sm text-gray-500 mt-1">Review merchant KYC submissions</p>
        </div>
        <div :if={@verifications_loaded?} class="flex items-center gap-2">
          <.severity_pill label={"#{@pending_count} pending"} tone="amber" />
          <.severity_pill label={"#{@approved_count} approved"} tone="green" />
        </div>
      </div>

      <%!-- Split view: queue + review panel --%>
      <div class="flex flex-col lg:flex-row bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden lg:h-[calc(100vh-15rem)] lg:min-h-[560px]">
        <%!-- Submission queue --%>
        <div class="w-full lg:w-[360px] shrink-0 border-b lg:border-b-0 lg:border-r border-gray-100 flex flex-col max-h-96 lg:max-h-none">
          <div class="p-4 border-b border-gray-100">
            <div class="flex items-center gap-1.5 flex-wrap">
              <button
                type="button"
                id="verification-filter-pending"
                phx-click="filter"
                phx-value-status="pending"
                class={filter_chip_classes(@filter == :pending)}
              >
                Pending <span class="opacity-60 tabular-nums">{@pending_count}</span>
              </button>
              <button
                type="button"
                id="verification-filter-approved"
                phx-click="filter"
                phx-value-status="approved"
                class={filter_chip_classes(@filter == :approved)}
              >
                Approved <span class="opacity-60 tabular-nums">{@approved_count}</span>
              </button>
              <button
                type="button"
                id="verification-filter-rejected"
                phx-click="filter"
                phx-value-status="rejected"
                class={filter_chip_classes(@filter == :rejected)}
              >
                Rejected <span class="opacity-60 tabular-nums">{@rejected_count}</span>
              </button>
              <button
                type="button"
                id="verification-filter-all"
                phx-click="filter"
                phx-value-status="all"
                class={filter_chip_classes(is_nil(@filter))}
              >
                All <span class="opacity-60 tabular-nums">{@total_count}</span>
              </button>
            </div>
          </div>
          <div
            id="platform-verifications"
            phx-update="stream"
            data-count={@verifications_count}
            class="flex-1 overflow-y-auto p-2"
          >
            <div
              :if={!@verifications_loaded?}
              id="platform-verifications-loading"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              Loading submissions…
            </div>
            <div
              :if={@verifications_loaded? && @verifications_count == 0}
              id="platform-verifications-empty"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              No submissions
            </div>
            <div
              :for={{id, %{verification: v, selected?: selected?}} <- @streams.verifications}
              id={id}
              role="button"
              tabindex="0"
              phx-click="select_verification"
              phx-value-id={v.id}
              data-selected={selected?}
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-[10px] cursor-pointer transition-colors",
                if(selected?,
                  do: "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <.store_avatar
                :if={v.store}
                store={v.store}
                class="w-9 h-9 rounded-[9px] text-[13px]"
              />
              <div class="min-w-0 flex-1">
                <p class={[
                  "text-[13.5px] font-semibold leading-tight truncate",
                  if(selected?, do: "text-gray-900", else: "text-slate-700")
                ]}>
                  {store_name(v)}
                </p>
                <p class="text-[11px] text-gray-400 truncate leading-tight mt-0.5">
                  {"#{v.business_name}#{if v.submitted_at, do: " · #{Calendar.strftime(v.submitted_at, "%b %d")}"}"}
                </p>
              </div>
              <span class={["w-2 h-2 rounded-full shrink-0", status_dot(v.status)]}></span>
            </div>
          </div>
        </div>

        <%!-- Review panel --%>
        <div class="flex-1 min-w-0 overflow-y-auto">
          <div :if={@selected} id="verification-panel" class="p-6 lg:p-7">
            <%!-- Identity --%>
            <div class="flex flex-wrap items-start gap-3">
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <h2 class="text-xl font-bold text-gray-900 tracking-tight truncate">
                    {@selected.business_name}
                  </h2>
                  <span id="verification-status">
                    <.severity_pill
                      label={status_label(@selected.status)}
                      tone={status_tone(@selected.status)}
                    />
                  </span>
                </div>
                <p class="text-[13px] text-gray-500 mt-0.5 truncate">
                  {"#{store_name(@selected)}#{if @selected.submitted_at, do: " · Submitted #{Calendar.strftime(@selected.submitted_at, "%b %d, %Y")}"}"}
                </p>
              </div>
              <.link
                :if={@selected.store}
                navigate={~p"/platform/stores/#{@selected.store_id}"}
                class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-blue-600 bg-white ring-1 ring-inset ring-gray-200 hover:bg-slate-50 transition-colors shrink-0"
              >
                Open store <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
              </.link>
            </div>

            <%!-- Documents --%>
            <div class="flex flex-col sm:flex-row gap-4 mt-5">
              <div class="flex-1 min-w-0">
                <div class="h-48 rounded-xl bg-gradient-to-br from-slate-100 to-slate-50 relative overflow-hidden flex items-center justify-center">
                  <img
                    :if={@business_doc_url}
                    src={@business_doc_url}
                    alt=""
                    class="absolute inset-0 w-full h-full object-cover"
                  />
                  <.icon
                    :if={!@business_doc_url}
                    name="hero-document-text"
                    class="size-9 text-slate-300"
                  />
                  <span class="absolute bottom-2 left-2.5 text-[11px] font-semibold text-slate-600 bg-white/85 px-2 py-0.5 rounded-full">
                    Business registration
                  </span>
                  <a
                    :if={@business_doc_url}
                    href={@business_doc_url}
                    target="_blank"
                    aria-label="Open business document"
                    class="absolute top-2 right-2 flex w-7 h-7 items-center justify-center rounded-full bg-white/90 text-slate-600 shadow hover:bg-white transition-colors"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
                  </a>
                </div>
              </div>
            </div>

            <div class="h-px bg-gray-100 my-6"></div>

            <div class="flex flex-col xl:flex-row gap-7">
              <%!-- Decision / outcome --%>
              <div class="flex-1 min-w-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  {if @selected.status == :pending, do: "Decision", else: "Review outcome"}
                </p>
                <div :if={@selected.status == :pending} class="border border-gray-200 rounded-xl p-4">
                  <.form for={@reject_form} id="verification-reject-form" phx-submit="confirm_reject">
                    <.input
                      field={@reject_form[:reason]}
                      type="textarea"
                      id="verification-reject-reason"
                      rows="2"
                      placeholder="Rejection reason — shown to the merchant…"
                      class="w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 focus:bg-white"
                    />
                    <div class="mt-3 flex items-center justify-between gap-3">
                      <button
                        type="submit"
                        class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-rose-700 bg-rose-50 ring-1 ring-inset ring-rose-600/20 hover:bg-rose-100 transition-colors"
                      >
                        Reject
                      </button>
                      <button
                        type="button"
                        id="panel-approve"
                        phx-click="approve"
                        class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-green-600 hover:bg-green-500 transition-colors"
                      >
                        <.icon name="hero-check-circle" class="size-4" /> Approve — award Verified
                      </button>
                    </div>
                  </.form>
                  <p class="text-[11px] text-gray-400 mt-2.5">
                    Approval awards the store's Verified badge. A rejection reason is shown to the
                    merchant, who can resubmit.
                  </p>
                </div>
                <div
                  :if={@selected.status == :approved}
                  class="rounded-xl p-4 bg-green-50 ring-1 ring-inset ring-green-600/20"
                >
                  <div class="flex items-start gap-2.5">
                    <.icon name="hero-check-circle" class="size-4 text-green-700 shrink-0 mt-0.5" />
                    <div class="min-w-0">
                      <p class="text-[13px] font-bold text-green-800">
                        {"Approved#{if @selected.reviewed_at, do: " · #{Calendar.strftime(@selected.reviewed_at, "%b %d, %Y")}"}"}
                      </p>
                      <p class="text-[13px] text-green-900 mt-0.5">
                        The store carries the Verified badge.
                      </p>
                    </div>
                  </div>
                </div>
                <div
                  :if={@selected.status == :rejected}
                  id="panel-review-banner"
                  class="rounded-xl p-4 bg-rose-50 ring-1 ring-inset ring-rose-200"
                >
                  <div class="flex items-start gap-2.5">
                    <.icon
                      name="hero-exclamation-triangle"
                      class="size-4 text-rose-600 shrink-0 mt-0.5"
                    />
                    <div class="min-w-0">
                      <p class="text-[13px] font-bold text-rose-700">
                        {"Rejected#{if @selected.reviewed_at, do: " · #{Calendar.strftime(@selected.reviewed_at, "%b %d, %Y")}"}"}
                      </p>
                      <p :if={@selected.review_reason} class="text-[13px] text-rose-900 mt-0.5">
                        {@selected.review_reason}
                      </p>
                    </div>
                  </div>
                  <p class="text-[11px] text-rose-700/75 mt-3">
                    The merchant sees this reason and can resubmit with corrected documents.
                  </p>
                </div>
              </div>

              <%!-- Review history --%>
              <div class="w-full xl:w-[250px] shrink-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  Review history
                </p>
                <div id="panel-history" class="flex flex-col gap-3">
                  <p :if={@history == []} class="text-[13px] text-gray-400">No decisions yet.</p>
                  <div :for={entry <- @history} class="flex items-start gap-2.5">
                    <span class={[
                      "flex w-7 h-7 items-center justify-center rounded-lg shrink-0",
                      history_chip_class(entry.action)
                    ]}>
                      <.icon name={history_icon(entry.action)} class="size-3.5" />
                    </span>
                    <div class="min-w-0">
                      <p class="text-[12.5px] font-semibold text-gray-900 leading-snug">
                        {history_label(entry.action)}
                      </p>
                      <p :if={entry.metadata["reason"]} class="text-xs text-gray-600 leading-snug">
                        {entry.metadata["reason"]}
                      </p>
                      <p class="text-[11px] text-gray-400 leading-snug mt-0.5">
                        {"#{Calendar.strftime(entry.inserted_at, "%b %d")} · #{Map.get(@history_actors, entry.actor_id, "system")}"}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div :if={@verifications_loaded? && is_nil(@selected)} class="p-6 lg:p-7">
            <.platform_empty_state
              icon="hero-identification"
              title="No submission selected"
              description="Choose a submission from the queue to review it."
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
