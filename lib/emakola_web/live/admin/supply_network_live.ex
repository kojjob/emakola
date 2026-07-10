defmodule EmakolaWeb.Admin.SupplyNetworkLive do
  @moduledoc "Merchant UI for SP2 wholesaler/reseller supply connections."
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Network

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Earn Network",
       active_nav: :supply_network,
       connection_count: 0,
       form: connection_form()
     )
     |> load_connections()}
  end

  @impl true
  def handle_event("request_connection", %{"connection" => params}, socket) do
    store = socket.assigns.current_store
    actor = socket.assigns.current_merchant
    slug = params |> Map.get("partner_slug", "") |> String.trim()

    case Emakola.Stores.get_store_by_slug(slug, authorize?: false) do
      {:ok, partner} ->
        attrs = connection_attrs(store.id, partner.id, params["relationship"])

        case Network.request(actor, attrs) do
          {:ok, _connection} ->
            {:noreply,
             socket
             |> assign(:form, connection_form())
             |> load_connections()
             |> put_flash(:info, "Invitation sent to #{partner.name}.")}

          {:error, :connection_exists} ->
            {:noreply, put_flash(socket, :error, "A connection with this store already exists.")}

          {:error, :stores_must_differ} ->
            {:noreply, put_flash(socket, :error, "Choose another store, not your own.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "The invitation could not be sent.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No store was found with that Makola address.")}
    end
  end

  def handle_event("approve_connection", %{"id" => id}, socket),
    do: update_connection(socket, id, &Network.approve/2, "Connection approved.")

  def handle_event("reject_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.reject(&1, &2, "Declined by partner"),
      "Invitation declined."
    )
  end

  def handle_event("suspend_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.suspend(&1, &2, "Paused by merchant"),
      "Connection paused."
    )
  end

  def handle_event("reactivate_connection", %{"id" => id}, socket),
    do: update_connection(socket, id, &Network.reactivate/2, "Connection reactivated.")

  def handle_event("terminate_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.terminate(&1, &2, "Ended by merchant"),
      "Connection ended."
    )
  end

  defp update_connection(socket, id, callback, success_message) do
    actor = socket.assigns.current_merchant

    with {:ok, connection} <- Network.get(actor, id),
         {:ok, _updated} <- callback.(actor, connection) do
      {:noreply, socket |> load_connections() |> put_flash(:info, success_message)}
    else
      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You cannot perform that action.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The connection could not be updated.")}
    end
  end

  defp load_connections(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    connections =
      case Network.list_for_store(actor, store.id) do
        {:ok, rows} -> Ash.load!(rows, [:wholesaler_store, :reseller_store], authorize?: false)
        _ -> []
      end

    socket
    |> assign(:connection_count, length(connections))
    |> stream(:connections, connections, reset: true)
  end

  defp connection_attrs(current_store_id, partner_store_id, "supply") do
    %{
      wholesaler_store_id: current_store_id,
      reseller_store_id: partner_store_id,
      requested_by_store_id: current_store_id
    }
  end

  defp connection_attrs(current_store_id, partner_store_id, _resell) do
    %{
      wholesaler_store_id: partner_store_id,
      reseller_store_id: current_store_id,
      requested_by_store_id: current_store_id
    }
  end

  defp connection_form do
    to_form(%{"partner_slug" => "", "relationship" => "resell"}, as: :connection)
  end

  defp partner(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: connection.reseller_store,
      else: connection.wholesaler_store
  end

  defp incoming?(connection, current_store_id) do
    connection.status == :pending and connection.requested_by_store_id != current_store_id
  end

  defp relationship_label(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: "You supply this store",
      else: "You sell this store's products"
  end

  defp status_classes(:active), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp status_classes(:pending), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  defp status_classes(:suspended), do: "bg-slate-100 text-slate-600 ring-slate-500/20"
  defp status_classes(:rejected), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp status_classes(:terminated), do: "bg-slate-100 text-slate-500 ring-slate-500/20"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="supply-network-page" class="mx-auto max-w-6xl space-y-8 px-4 sm:px-6">
      <header class="overflow-hidden rounded-3xl bg-slate-950 px-6 py-8 text-white shadow-xl sm:px-10">
        <div class="max-w-2xl">
          <span class="inline-flex items-center gap-2 rounded-full bg-emerald-400/10 px-3 py-1 text-xs font-semibold text-emerald-300 ring-1 ring-emerald-400/20">
            <.icon name="hero-sparkles" class="size-4" /> Makola Earn
          </span>
          <h1 class="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">
            Earn without buying stock
          </h1>
          <p class="mt-3 max-w-xl text-sm leading-6 text-slate-300 sm:text-base">
            Connect with another verified store. They hold the products, you bring the customers,
            and Makola keeps each relationship visible and controlled by both parties.
          </p>
        </div>
      </header>

      <section
        id="connection-invite-panel"
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7"
      >
        <div class="mb-5">
          <h2 class="text-lg font-semibold text-slate-900">Invite a store</h2>
          <p class="mt-1 text-sm text-slate-500">
            Enter the store name from its Makola address, for example <span class="font-medium">kente-kingdom</span>.
          </p>
        </div>

        <.form
          for={@form}
          id="supply-connection-form"
          phx-submit="request_connection"
          class="grid gap-4 md:grid-cols-[1fr_1fr_auto] md:items-end"
        >
          <.input
            field={@form[:partner_slug]}
            type="text"
            label="Store address"
            placeholder="store-name"
            required
          />
          <.input
            field={@form[:relationship]}
            type="select"
            label="What do you want to do?"
            options={[
              {"Sell their products", "resell"},
              {"Supply products to them", "supply"}
            ]}
          />
          <button
            id="send-connection-invite"
            type="submit"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-emerald-600 px-5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-emerald-700 hover:shadow-md"
          >
            <.icon name="hero-paper-airplane" class="size-4" /> Send invite
          </button>
        </.form>
      </section>

      <section aria-labelledby="connections-heading" class="space-y-4">
        <div class="flex items-end justify-between gap-4">
          <div>
            <h2 id="connections-heading" class="text-xl font-semibold text-slate-900">
              Your connections
            </h2>
            <p class="mt-1 text-sm text-slate-500">
              Both stores must agree before products can be shared.
            </p>
          </div>
          <span
            id="connection-count"
            class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
          >
            {@connection_count}
          </span>
        </div>

        <div id="supply-connections" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
          <div
            id="connections-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"
          >
            <.icon name="hero-link" class="mx-auto size-9 text-slate-300" />
            <p class="mt-3 text-sm font-semibold text-slate-700">No network connections yet</p>
            <p class="mt-1 text-xs text-slate-500">
              Invite a trusted store to start building your supplier network.
            </p>
          </div>

          <article
            :for={{dom_id, connection} <- @streams.connections}
            id={dom_id}
            class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-slate-300 hover:shadow-md"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex min-w-0 items-center gap-3">
                <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
                  <.icon name="hero-building-storefront" class="size-5" />
                </div>
                <div class="min-w-0">
                  <h3 class="truncate font-semibold text-slate-900">
                    {partner(connection, @current_store.id).name}
                  </h3>
                  <p class="truncate text-xs text-slate-500">
                    @{partner(connection, @current_store.id).slug}
                  </p>
                </div>
              </div>
              <span class={[
                "rounded-full px-2.5 py-1 text-[11px] font-semibold capitalize ring-1 ring-inset",
                status_classes(connection.status)
              ]}>
                {connection.status}
              </span>
            </div>

            <p class="mt-4 text-sm text-slate-600">
              {relationship_label(connection, @current_store.id)}
            </p>
            <p :if={connection.status_reason} class="mt-1 text-xs text-slate-400">
              {connection.status_reason}
            </p>

            <div class="mt-5 flex flex-wrap gap-2 border-t border-slate-100 pt-4">
              <%= if incoming?(connection, @current_store.id) do %>
                <button
                  id={"approve-connection-#{connection.id}"}
                  phx-click="approve_connection"
                  phx-value-id={connection.id}
                  class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
                >
                  Accept
                </button>
                <button
                  id={"reject-connection-#{connection.id}"}
                  phx-click="reject_connection"
                  phx-value-id={connection.id}
                  class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600 transition hover:bg-slate-50"
                >
                  Decline
                </button>
              <% end %>
              <button
                :if={connection.status == :active}
                id={"suspend-connection-#{connection.id}"}
                phx-click="suspend_connection"
                phx-value-id={connection.id}
                class="rounded-lg border border-amber-200 px-3 py-2 text-xs font-semibold text-amber-700 transition hover:bg-amber-50"
              >
                Pause
              </button>
              <button
                :if={connection.status == :suspended}
                id={"reactivate-connection-#{connection.id}"}
                phx-click="reactivate_connection"
                phx-value-id={connection.id}
                class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
              >
                Reactivate
              </button>
              <button
                :if={connection.status in [:pending, :active, :suspended]}
                id={"terminate-connection-#{connection.id}"}
                phx-click="terminate_connection"
                phx-value-id={connection.id}
                class="ml-auto rounded-lg px-3 py-2 text-xs font-semibold text-rose-600 transition hover:bg-rose-50"
              >
                End connection
              </button>
            </div>
          </article>
        </div>
      </section>
    </div>
    """
  end
end
