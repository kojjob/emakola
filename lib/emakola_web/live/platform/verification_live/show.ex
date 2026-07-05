defmodule EmakolaWeb.Platform.VerificationLive.Show do
  @moduledoc """
  Platform admin detail page for one store KYC submission — the home for
  approve / reject.

  Gated by RequirePermission (:manage_merchants). Documents are shown via
  short-lived presigned URLs (never public). Approve awards the Store.verified
  badge; both decisions are audited and notify the merchant. Every action
  re-checks the permission against a freshly reloaded user.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  require Ash.Query

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Notifications.Workers.VerificationStatusNotificationWorker
  alias Emakola.Stores

  @verification_actions [:verification_approved, :verification_rejected]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Verification")
      |> assign(:active_nav, :verifications)
      |> assign(:id, id)
      |> assign(:verification, nil)
      |> assign(:store, nil)
      |> assign(:id_document_url, nil)
      |> assign(:business_doc_url, nil)
      |> assign(:reject_modal, false)
      |> assign(:history, [])
      |> assign(:history_actors, %{})
      |> assign(:not_found, false)

    {:ok, if(connected?(socket), do: load(socket, id), else: socket)}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    authorized(socket, fn socket ->
      decide(
        socket,
        Stores.approve_store_verification(socket.assigns.verification, %{}, authorize?: false),
        event: :verification_approved,
        verified: true,
        reason: nil,
        flash: "Verification approved."
      )
    end)
  end

  def handle_event("open_reject_modal", _params, socket) do
    {:noreply, assign(socket, :reject_modal, true)}
  end

  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, :reject_modal, false)}
  end

  def handle_event("confirm_reject", %{"reason" => reason}, socket) do
    authorized(socket, fn socket ->
      reason = String.trim(reason || "")

      if reason == "" do
        {:noreply, put_flash(socket, :error, "A reason is required.")}
      else
        decide(
          socket,
          Stores.reject_store_verification(socket.assigns.verification, %{reason: reason},
            authorize?: false
          ),
          event: :verification_rejected,
          verified: false,
          reason: reason,
          flash: "Verification rejected."
        )
      end
    end)
  end

  defp decide(socket, {:ok, updated}, opts) do
    store = socket.assigns.store
    event = Keyword.fetch!(opts, :event)
    reason = Keyword.get(opts, :reason)

    set_verified(store, Keyword.fetch!(opts, :verified))
    PlatformAudit.log(event, socket.assigns.current_user, audit_metadata(store, reason))
    VerificationStatusNotificationWorker.enqueue(store.id, event)

    {:noreply,
     socket
     |> assign(:verification, updated)
     |> assign(:reject_modal, false)
     |> load_history(store.id)
     |> put_flash(:info, Keyword.fetch!(opts, :flash))}
  end

  defp decide(socket, {:error, _}, _opts) do
    {:noreply, put_flash(socket, :error, "Could not update the submission.")}
  end

  defp set_verified(%{} = store, value) do
    Stores.update_store_directory_meta(store, %{verified: value}, authorize?: false)
  end

  defp audit_metadata(store, reason) do
    base = %{"store_id" => store.id, "store_name" => store.name}
    if reason, do: Map.put(base, "reason", reason), else: base
  end

  # ── Permission gating ───────────────────────────────────────────

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

  # ── Loading ─────────────────────────────────────────────────────

  defp load(socket, id) do
    case Ash.get(Emakola.Stores.StoreVerification, id, load: [:store], authorize?: false) do
      {:ok, verification} ->
        socket
        |> assign(:verification, verification)
        |> assign(:store, verification.store)
        |> assign(:id_document_url, doc_url(verification.id_document_key))
        |> assign(:business_doc_url, doc_url(verification.business_doc_key))
        |> load_history(verification.store_id)

      _ ->
        assign(socket, :not_found, true)
    end
  end

  defp doc_url(nil), do: nil

  defp doc_url(key) do
    case Emakola.Storage.presigned_url(key, expires_in: 900) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp load_history(socket, store_id) do
    entries =
      case PlatformAuditLog
           |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
           |> Ash.read(authorize?: false) do
        {:ok, list} -> Enum.filter(list, &(&1.action in @verification_actions))
        _ -> []
      end

    assign(socket, history: entries, history_actors: actor_emails(entries))
  rescue
    exception ->
      Logger.error(
        "[platform.verification_live] load_history loading review history raised: #{Exception.message(exception)}"
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
    <div class="p-6 lg:p-8 max-w-3xl mx-auto">
      <.link navigate={~p"/platform/verifications"} class="text-sm text-gray-500 hover:text-gray-700">
        ← Back to verifications
      </.link>

      <div :if={@not_found} class="mt-8 rounded-xl border border-gray-200 bg-white p-12 text-center">
        <p class="text-gray-500">Submission not found.</p>
      </div>

      <div
        :if={is_nil(@verification) and not @not_found}
        class="mt-8 rounded-xl border border-gray-200 bg-white p-12 text-center text-gray-400"
      >
        Loading…
      </div>

      <div :if={@verification} class="mt-4">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-900">{@store && @store.name}</h1>
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
            status_class(@verification.status)
          ]}>
            {status_label(@verification.status)}
          </span>
        </div>

        <div :if={@verification.status == :pending} class="mt-5 flex gap-2">
          <button
            type="button"
            phx-click="approve"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-green-100 text-green-700 hover:bg-green-200"
          >
            Approve
          </button>
          <button
            type="button"
            phx-click="open_reject_modal"
            class="px-3 py-1.5 rounded-lg text-sm font-medium bg-red-100 text-red-700 hover:bg-red-200"
          >
            Reject
          </button>
        </div>

        <dl class="mt-6 grid gap-4 sm:grid-cols-2">
          <.field label="Business name" value={@verification.business_name} />
          <.field label="ID type" value={id_type_label(@verification.id_type)} />
          <.field label="ID number" value={@verification.id_number} />
          <.field
            label="Submitted"
            value={
              @verification.submitted_at &&
                Calendar.strftime(@verification.submitted_at, "%b %d, %Y %H:%M")
            }
          />
        </dl>

        <div class="mt-6 flex flex-wrap gap-3">
          <a
            :if={@id_document_url}
            href={@id_document_url}
            target="_blank"
            class="inline-flex items-center gap-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-blue-600 hover:bg-gray-50"
          >
            View ID document <span class="material-symbols-outlined text-sm">open_in_new</span>
          </a>
          <a
            :if={@business_doc_url}
            href={@business_doc_url}
            target="_blank"
            class="inline-flex items-center gap-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-blue-600 hover:bg-gray-50"
          >
            View business document <span class="material-symbols-outlined text-sm">open_in_new</span>
          </a>
        </div>

        <div
          :if={@verification.status == :rejected and @verification.review_reason}
          class="mt-6 rounded-lg border border-gray-200 bg-gray-50 p-4"
        >
          <p class="text-xs font-medium uppercase tracking-wide text-gray-500">Rejection reason</p>
          <p class="mt-1 text-sm text-gray-800">{@verification.review_reason}</p>
        </div>

        <div class="mt-8">
          <h2 class="text-sm font-semibold text-gray-900">Review history</h2>
          <div class="mt-3 rounded-xl border border-gray-200 bg-white divide-y divide-gray-100">
            <p :if={@history == []} class="p-4 text-sm text-gray-400">No decisions yet.</p>
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

      <div
        :if={@reject_modal}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      >
        <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl" phx-click-away="cancel_modal">
          <h3 class="text-lg font-semibold text-gray-900">Reject submission</h3>
          <p class="mt-1 text-sm text-gray-500">
            The reason is shown to the merchant so they can fix and resubmit.
          </p>
          <form phx-submit="confirm_reject" class="mt-4">
            <label class="block text-sm font-medium text-gray-700">Reason (required)</label>
            <textarea
              name="reason"
              rows="3"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-blue-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
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
                Reject
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp field(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-medium uppercase tracking-wide text-gray-400">{@label}</dt>
      <dd class="mt-1 text-sm font-medium text-gray-900">{@value || "—"}</dd>
    </div>
    """
  end

  defp status_class(:pending), do: "bg-amber-100 text-amber-700"
  defp status_class(:approved), do: "bg-green-100 text-green-700"
  defp status_class(:rejected), do: "bg-red-100 text-red-700"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp history_label(action),
    do: action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp id_type_label(:ghana_card), do: "Ghana Card"
  defp id_type_label(:passport), do: "Passport"
  defp id_type_label(:drivers_license), do: "Driver's License"
  defp id_type_label(:voter_id), do: "Voter ID"
  defp id_type_label(other), do: to_string(other)
end
