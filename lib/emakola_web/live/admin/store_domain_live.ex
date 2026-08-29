defmodule EmakolaWeb.Admin.StoreDomainLive do
  @moduledoc """
  Where a merchant connects their own domain.

  Editing DNS at a registrar is the most technical thing this product asks of
  anyone, and these merchants are often not strong readers. So the page is
  built around the few things that carry meaning without prose: the records
  themselves in a table, a copy button on every value, a numbered stepper, and
  a "send to WhatsApp" hand-off — because the person who owns the shop
  frequently is not the person holding the registrar login.

  Status comes from the domain row, which the verification worker updates, so
  the merchant sees real progress rather than a spinner that means nothing.
  """

  use EmakolaWeb, :live_view

  alias Emakola.Stores
  alias Emakola.Stores.DomainInstructions
  alias Emakola.Stores.Domains

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Your own domain", error: nil) |> load_domains()}
  end

  @impl true
  def handle_event("claim", %{"host" => host}, socket) do
    case Domains.claim(socket.assigns.current_store, host) do
      {:ok, _domains} ->
        {:noreply, socket |> assign(error: nil) |> load_domains()}

      {:error, reason} ->
        {:noreply, assign(socket, error: humanize(reason))}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    with {:ok, domain} <- fetch_own_domain(socket, id),
         {:ok, _} <- Domains.revoke(domain, "Removed by the shop owner") do
      {:noreply, load_domains(socket)}
    else
      _ -> {:noreply, assign(socket, error: "We could not remove that domain.")}
    end
  end

  # Authorization is re-checked here, not just at render: an event carries
  # whatever id the client sends.
  defp fetch_own_domain(socket, id) do
    case Enum.find(socket.assigns.domains, &(&1.id == id)) do
      nil -> :error
      domain -> {:ok, domain}
    end
  end

  defp load_domains(socket) do
    {:ok, all} =
      Stores.list_store_domains(socket.assigns.current_store.id, authorize?: false)

    custom = Enum.filter(all, &(&1.type == :custom and &1.status != :expired))

    assign(socket, domains: custom, primary: Enum.find(custom, & &1.serve_in_place?))
  end

  defp humanize(%{errors: [%{message: message} | _]}), do: message
  defp humanize(reason) when is_binary(reason), do: reason
  defp humanize(_), do: "That address cannot be used."

  # ── presentation ──────────────────────────────────────────────────────────

  defp step(:pending), do: 1
  defp step(:verifying), do: 2
  defp step(:active), do: 3
  defp step(_), do: 1

  defp tone(:active), do: "bg-emerald-50 text-emerald-700 border-emerald-200"
  defp tone(:verifying), do: "bg-amber-50 text-amber-700 border-amber-200"
  defp tone(_), do: "bg-slate-50 text-slate-600 border-slate-200"

  defp state_icon(:active), do: "hero-check-circle"
  defp state_icon(:verifying), do: "hero-arrow-path"
  defp state_icon(_), do: "hero-clock"

  defp state_words(:active), do: "Your domain is live"
  defp state_words(:verifying), do: "Checking your domain"
  defp state_words(_), do: "Add these to your domain"

  defp whatsapp_link(host, records) do
    lines =
      Enum.map_join(records, "%0A", fn r -> "#{r.type}  #{r.name}  #{r.value}" end)

    "https://wa.me/?text=DNS%20for%20#{host}:%0A#{lines}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_page_header
      title="Your own domain"
      subtitle="Show your shop on a web address you own"
      icon="hero-globe-alt"
    />

    <div :if={@error} class="mb-4 rounded-card border border-red-200 bg-red-50 p-4">
      <div class="flex items-center gap-3">
        <.icon name="hero-exclamation-triangle" class="size-6 text-red-600 shrink-0" />
        <p class="text-sm font-semibold text-red-800">{@error}</p>
      </div>
    </div>

    <div :for={domain <- @domains} class="mb-6 rounded-card border border-slate-200 bg-white p-5">
      <div class="flex items-center gap-3 mb-5">
        <span class={"inline-flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm font-semibold #{tone(domain.status)}"}>
          <.icon name={state_icon(domain.status)} class="size-5" />
          {state_words(domain.status)}
        </span>
        <span class="font-mono text-base font-bold text-slate-900">{domain.host}</span>
      </div>

      <ol class="flex items-center gap-2 mb-5" aria-label="Steps">
        <li :for={n <- 1..3} class="flex items-center gap-2">
          <span class={[
            "w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold",
            if(step(domain.status) >= n,
              do: "bg-primary text-white",
              else: "bg-slate-100 text-slate-400"
            )
          ]}>
            {n}
          </span>
          <span :if={n < 3} class="w-8 h-px bg-slate-200"></span>
        </li>
      </ol>

      <p :if={domain.status_reason} class="mb-4 text-sm font-medium text-amber-700">
        {domain.status_reason}
      </p>

      <div :if={domain.status != :active}>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-slate-500">
                <th class="pb-2 pr-4 font-semibold">Type</th>
                <th class="pb-2 pr-4 font-semibold">Name</th>
                <th class="pb-2 font-semibold">Points to</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={record <- DomainInstructions.records_for(domain.host)}
                class="border-t border-slate-100"
              >
                <td class="py-3 pr-4">
                  <span class="inline-flex items-center gap-1.5 px-2 py-1 rounded bg-slate-100 font-mono text-xs font-bold text-slate-700">
                    <.icon name={record.icon} class="size-4" />{record.type}
                  </span>
                </td>
                <td class="py-3 pr-4 font-mono text-slate-900">{record.name}</td>
                <td class="py-3">
                  <button
                    type="button"
                    phx-click="copy"
                    data-copy={record.value}
                    class="inline-flex items-center gap-2 font-mono text-slate-900 hover:text-primary"
                  >
                    {record.value}
                    <.icon name="hero-clipboard-document" class="size-4 text-slate-400" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <a
          href={whatsapp_link(domain.host, DomainInstructions.records_for(domain.host))}
          target="_blank"
          rel="noopener"
          class="mt-4 inline-flex items-center gap-2 px-4 py-2.5 rounded-control bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-5" /> Send to WhatsApp
        </a>
      </div>

      <a
        :if={domain.status == :active}
        href={"https://#{domain.host}"}
        target="_blank"
        rel="noopener"
        class="inline-flex items-center gap-2 text-lg font-bold text-primary hover:underline"
      >
        {domain.host} <.icon name="hero-arrow-top-right-on-square" class="size-5" />
      </a>

      <button
        type="button"
        phx-click="remove"
        phx-value-id={domain.id}
        data-confirm="Remove this domain? Your shop will go back to its Makola address."
        class="mt-4 block text-sm font-semibold text-slate-500 hover:text-red-600"
      >
        Remove
      </button>
    </div>

    <div :if={@domains == []} class="rounded-card border border-slate-200 bg-white p-6">
      <.form
        for={%{}}
        as={:domain}
        id="claim-domain-form"
        phx-submit="claim"
        class="flex flex-col sm:flex-row gap-3"
      >
        <input
          type="text"
          name="host"
          placeholder="yourshop.com"
          autocomplete="off"
          class="flex-1 rounded-control border-slate-300 font-mono text-base"
        />
        <button
          type="submit"
          class="inline-flex items-center justify-center gap-2 px-5 py-3 rounded-control bg-primary text-white font-semibold hover:bg-primary-hover"
        >
          <.icon name="hero-plus-circle" class="size-5" /> Add domain
        </button>
      </.form>
    </div>
    """
  end
end
