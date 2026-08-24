defmodule EmakolaWeb.Platform.DomainLive.Index do
  @moduledoc """
  Staff review queue for merchant custom domains.

  Approval sits at the *front* of the lifecycle, not the end: a human looks at
  a claim before we spend a Fly certificate slot and Let's Encrypt quota on
  it. That is the point at which a squatted or abusive domain can still be
  stopped — once a certificate issues there is nothing useful left for a
  person to add.

  **Approving transitions state and nothing else.** It never calls Fly. That
  is deliberate: it keeps this queue independent of the certificate worker, so
  a `:verifying` row simply waits until that worker exists, invisible to
  routing (both plugs match `:active`).

  Mount is gated on `:manage_stores`, no queries run during the disconnected
  render, and every mutating event re-checks the permission against a freshly
  reloaded user so a revocation after mount is caught before the write.
  """

  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Stores
  alias Emakola.Stores.DomainInstructions
  alias Emakola.Stores.Domains

  @filters [:pending, :verifying, :active, :expired]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Domains", active_nav: :stores)
     |> assign(filter: :pending, loaded?: false, domains: [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filter = Emakola.SafeAtom.to_atom_in(status, @filters, :pending)
    {:noreply, socket |> assign(filter: filter) |> load()}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    act(socket, id, :domain_approved, &Domains.request_verification/1)
  end

  def handle_event("reject", %{"id" => id}, socket) do
    act(socket, id, :domain_rejected, fn domain ->
      Domains.revoke(domain, "Not approved by Makola. Contact support if this is a mistake.")
    end)
  end

  # Re-check the permission against a freshly reloaded user: an event carries
  # whatever the client sends, and a revocation after mount must be caught
  # before the write, not after.
  defp act(socket, id, action, fun) do
    with true <- permitted?(socket),
         {:ok, domain} <- fetch(socket, id),
         {:ok, updated} <- fun.(domain) do
      PlatformAudit.log(action, socket.assigns.current_user, %{
        host: updated.host,
        store_id: updated.store_id
      })

      {:noreply, load(socket)}
    else
      _ -> {:noreply, put_flash(socket, :error, "That domain could not be updated.")}
    end
  end

  defp permitted?(socket) do
    case Ash.get(Emakola.Accounts.User, socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> PlatformPermissions.allowed?(user, :manage_stores)
      _ -> false
    end
  end

  defp fetch(socket, id) do
    case Enum.find(socket.assigns.domains, &(&1.id == id)) do
      nil -> :error
      domain -> {:ok, domain}
    end
  end

  defp load(socket) do
    {:ok, domains} =
      Stores.list_custom_domains_for_review(%{status: socket.assigns.filter}, authorize?: false)

    assign(socket, domains: domains, loaded?: true)
  end

  defp tone(:active), do: "bg-emerald-50 text-emerald-700 border-emerald-200"
  defp tone(:verifying), do: "bg-amber-50 text-amber-700 border-amber-200"
  defp tone(:expired), do: "bg-slate-100 text-slate-500 border-slate-200"
  defp tone(_), do: "bg-sky-50 text-sky-700 border-sky-200"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :filters, @filters)

    ~H"""
    <.admin_page_header
      title="Domains"
      subtitle="Merchant custom domains awaiting review"
      icon="hero-globe-alt"
    />

    <div class="flex flex-wrap gap-2 mb-6">
      <button
        :for={status <- @filters}
        type="button"
        phx-click="filter"
        phx-value-status={status}
        class={[
          "px-4 py-2 rounded-control text-sm font-semibold capitalize transition-colors",
          if(@filter == status,
            do: "bg-primary text-white",
            else: "bg-white text-slate-600 border border-slate-200 hover:bg-slate-50"
          )
        ]}
      >
        {status}
      </button>
    </div>

    <p :if={@loaded? && @domains == []} class="text-sm text-slate-500">
      Nothing {@filter} right now.
    </p>

    <div
      :for={domain <- @domains}
      id={"domain-#{domain.id}"}
      class="mb-4 rounded-card border border-slate-200 bg-white p-5"
    >
      <div class="flex flex-wrap items-center gap-3 mb-4">
        <span class={"px-3 py-1 rounded-full border text-xs font-semibold capitalize #{tone(domain.status)}"}>
          {domain.status}
        </span>
        <span class="font-mono text-base font-bold text-slate-900">{domain.host}</span>
        <span class="text-sm text-slate-500">{domain.store && domain.store.name}</span>
      </div>

      <p :if={domain.status_reason} class="mb-3 text-sm text-slate-600">{domain.status_reason}</p>

      <details class="mb-4">
        <summary class="text-sm font-semibold text-slate-600 cursor-pointer">
          What the merchant was told to add
        </summary>
        <table class="mt-3 text-sm">
          <tr :for={record <- DomainInstructions.records_for(domain.host)}>
            <td class="pr-4 py-1 font-mono text-xs font-bold text-slate-500">{record.type}</td>
            <td class="pr-4 py-1 font-mono">{record.name}</td>
            <td class="py-1 font-mono">{record.value}</td>
          </tr>
        </table>
      </details>

      <div :if={domain.status == :pending} class="flex gap-3">
        <button
          type="button"
          phx-click="approve"
          phx-value-id={domain.id}
          class="px-4 py-2 rounded-control bg-primary text-white text-sm font-semibold hover:bg-primary-hover"
        >
          Approve
        </button>
        <button
          type="button"
          phx-click="reject"
          phx-value-id={domain.id}
          class="px-4 py-2 rounded-control border border-slate-200 text-slate-600 text-sm font-semibold hover:bg-slate-50"
        >
          Reject
        </button>
      </div>
    </div>
    """
  end
end
