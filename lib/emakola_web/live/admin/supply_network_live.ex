defmodule EmakolaWeb.Admin.SupplyNetworkLive do
  @moduledoc "Merchant UI for SP2 wholesaler/reseller supply connections."
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.{
    InboundFulfillment,
    ListingImporter,
    Network,
    Offers,
    SalesSharing
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Earn Network",
       active_nav: :supply_network,
       connection_count: 0,
       offer_count: 0,
       listing_count: 0,
       sales_share_count: 0,
       sales_click_count: 0,
       sales_order_count: 0,
       sales_revenue: 0,
       first_money: %{},
       active_connection?: false,
       inbound_count: 0,
       shipping_fulfillment_id: nil,
       shipping_form: to_form(%{"tracking_number" => ""}, as: :shipment),
       delivery_fulfillment_id: nil,
       delivery_form: to_form(%{"code" => ""}, as: :delivery),
       form: connection_form()
     )
     |> load_connections()
     |> load_earn_catalog()
     |> load_inbound_fulfillments()
     |> load_sales_journey()}
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

  def handle_event("import_offer", %{"id" => offer_id}, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    with {:ok, offers} <- Offers.list_available(actor, store.id),
         %{} = offer <- Enum.find(offers, &(&1.id == offer_id)),
         {:ok, _listing} <- ListingImporter.import(actor, store.id, offer) do
      {:noreply,
       socket
       |> load_earn_catalog()
       |> load_sales_journey()
       |> put_flash(:info, "Product added to your store. Its images are being prepared.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "This offer is no longer available.")}

      {:error, :listing_exists} ->
        {:noreply,
         socket
         |> load_earn_catalog()
         |> load_sales_journey()
         |> put_flash(:info, "Already in your store.")}

      _ ->
        {:noreply, put_flash(socket, :error, "This product could not be added right now.")}
    end
  end

  def handle_event("create_sales_kit", %{"id" => listing_id}, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    with {:ok, listings} <- ListingImporter.list(actor, store.id),
         %{} = listing <- Enum.find(listings, &(&1.id == listing_id)),
         {:ok, _shares} <- SalesSharing.create_kit(actor, listing) do
      {:noreply,
       socket
       |> load_sales_journey()
       |> put_flash(:info, "Sales kit ready. Share it where your customers already chat.")}
    else
      _ -> {:noreply, put_flash(socket, :error, "The sales kit could not be created.")}
    end
  end

  def handle_event("record_sales_share", %{"id" => share_id}, socket) do
    SalesSharing.record_share(
      socket.assigns.current_merchant,
      socket.assigns.current_store.id,
      share_id
    )

    {:noreply, load_sales_journey(socket)}
  end

  def handle_event("select_inbound_shipping", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(
       shipping_fulfillment_id: id,
       shipping_form: to_form(%{"tracking_number" => ""}, as: :shipment)
     )
     |> load_inbound_fulfillments()}
  end

  def handle_event("cancel_inbound_shipping", _params, socket) do
    {:noreply, socket |> assign(:shipping_fulfillment_id, nil) |> load_inbound_fulfillments()}
  end

  def handle_event("ship_inbound", %{"shipment" => params}, socket) do
    id = socket.assigns.shipping_fulfillment_id

    case InboundFulfillment.mark_shipped(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id,
           Map.get(params, "tracking_number", "")
         ) do
      {:ok, _fulfillment} ->
        {:noreply,
         socket
         |> assign(:shipping_fulfillment_id, nil)
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Shipment marked as on the way.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Shipment could not be updated.")}
    end
  end

  def handle_event("request_delivery_code", %{"id" => id}, socket) do
    case InboundFulfillment.request_delivery_code(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id
         ) do
      {:ok, _proof} ->
        {:noreply,
         socket
         |> assign(
           delivery_fulfillment_id: id,
           delivery_form: to_form(%{"code" => ""}, as: :delivery)
         )
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Delivery code sent to the customer.")}

      {:error, :customer_phone_missing} ->
        {:noreply, put_flash(socket, :error, "This order has no customer phone number.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The delivery code could not be sent.")}
    end
  end

  def handle_event("enter_delivery_code", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(
       delivery_fulfillment_id: id,
       delivery_form: to_form(%{"code" => ""}, as: :delivery)
     )
     |> load_inbound_fulfillments()}
  end

  def handle_event("verify_delivery", %{"delivery" => params}, socket) do
    case InboundFulfillment.verify_delivery(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           socket.assigns.delivery_fulfillment_id,
           Map.get(params, "code", "")
         ) do
      {:ok, _fulfillment} ->
        {:noreply,
         socket
         |> assign(:delivery_fulfillment_id, nil)
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Delivery confirmed by the customer.")}

      {:error, :invalid_code} ->
        {:noreply, put_flash(socket, :error, "That delivery code is not correct.")}

      {:error, :expired} ->
        {:noreply, put_flash(socket, :error, "That code has expired. Send a new one.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Delivery could not be confirmed.")}
    end
  end

  defp update_connection(socket, id, callback, success_message) do
    actor = socket.assigns.current_merchant

    with {:ok, connection} <- Network.get(actor, id),
         {:ok, _updated} <- callback.(actor, connection) do
      {:noreply,
       socket
       |> load_connections()
       |> load_earn_catalog()
       |> load_sales_journey()
       |> put_flash(:info, success_message)}
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
    |> assign(:active_connection?, Enum.any?(connections, &(&1.status == :active)))
    |> stream(:connections, connections, reset: true)
  end

  defp load_earn_catalog(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    offers = result_rows(Offers.list_available(actor, store.id))
    listings = result_rows(ListingImporter.list(actor, store.id))
    imported_offer_ids = MapSet.new(listings, & &1.offer_id)
    available = Enum.reject(offers, &MapSet.member?(imported_offer_ids, &1.id))

    socket
    |> assign(:offer_count, length(available))
    |> assign(:listing_count, length(listings))
    |> stream(:offers, available, reset: true)
    |> stream(:listings, listings, reset: true)
  end

  defp load_inbound_fulfillments(socket) do
    fulfillments =
      socket.assigns.current_merchant
      |> InboundFulfillment.list(socket.assigns.current_store.id)
      |> result_rows()

    socket
    |> assign(:inbound_count, length(fulfillments))
    |> stream(:inbound_fulfillments, fulfillments, reset: true)
  end

  defp load_sales_journey(socket) do
    shares =
      socket.assigns.current_merchant
      |> SalesSharing.list_for_store(socket.assigns.current_store.id)
      |> result_rows()

    share_count = Enum.reduce(shares, 0, &(&1.share_count + &2))
    click_count = Enum.reduce(shares, 0, &(&1.click_count + &2))
    order_count = Enum.reduce(shares, 0, &(&1.order_count + &2))
    revenue = Enum.reduce(shares, 0, &(&1.revenue + &2))

    delivered? =
      Enum.any?(shares, fn share ->
        Enum.any?(share.conversions, &SalesSharing.delivered_conversion?/1)
      end)

    first_money = %{
      connected: socket.assigns.active_connection?,
      listed: socket.assigns.listing_count > 0,
      shared: share_count > 0,
      sold: order_count > 0,
      fulfilled: delivered?
    }

    socket
    |> assign(:sales_share_count, length(shares))
    |> assign(:sales_click_count, click_count)
    |> assign(:sales_order_count, order_count)
    |> assign(:sales_revenue, revenue)
    |> assign(:first_money, first_money)
    |> stream(:sales_shares, shares, reset: true)
  end

  defp result_rows({:ok, rows}), do: rows
  defp result_rows(_error), do: []

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

  defp fulfillment_status_classes(:pending), do: "bg-amber-50 text-amber-700"
  defp fulfillment_status_classes(:notified), do: "bg-blue-50 text-blue-700"
  defp fulfillment_status_classes(:shipped), do: "bg-violet-50 text-violet-700"
  defp fulfillment_status_classes(:delivered), do: "bg-emerald-50 text-emerald-700"
  defp fulfillment_status_classes(:cancelled), do: "bg-slate-100 text-slate-500"

  defp shipment_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id
  defp delivery_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id

  defp customer_city(order) do
    address = order.shipping_address || %{}
    Map.get(address, "city") || Map.get(address, :city) || "Delivery address on order"
  end

  defp lead_image(offer), do: List.first(offer.source_product.images)

  defp earning_range(offer) do
    earnings = Enum.map(offer.offer_variants, &(&1.suggested_retail_price - &1.supplier_price))

    case Enum.min_max(earnings, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  defp retail_range(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)

    case Enum.min_max(prices, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  defp money(pesewas), do: "GH₵#{:erlang.float_to_binary(pesewas / 100, decimals: 2)}"

  defp sales_share_url(share), do: SalesSharing.url(share)
  defp sales_share_message(share), do: SalesSharing.message(share)

  defp whatsapp_share_url(share),
    do: "https://wa.me/?text=#{URI.encode_www_form(sales_share_message(share))}"

  defp facebook_share_url(share),
    do:
      "https://www.facebook.com/sharer/sharer.php?u=#{URI.encode_www_form(sales_share_url(share))}"

  defp channel_label(:whatsapp), do: "WhatsApp"
  defp channel_label(:facebook), do: "Facebook"
  defp channel_label(:copy_link), do: "Copy link"

  defp channel_icon(:whatsapp), do: "hero-chat-bubble-left-right"
  defp channel_icon(:facebook), do: "hero-user-group"
  defp channel_icon(:copy_link), do: "hero-link"

  defp journey_step(first_money, key, label, description) do
    %{
      key: key,
      complete?: Map.get(first_money, key, false),
      label: label,
      description: description
    }
  end

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

      <section id="earn-catalog" aria-labelledby="earn-catalog-heading" class="space-y-5">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-600">
              Earn catalog
            </span>
            <h2
              id="earn-catalog-heading"
              class="mt-1 text-2xl font-bold tracking-tight text-slate-950"
            >
              Products you can sell today
            </h2>
            <p class="mt-1 max-w-2xl text-sm text-slate-500">
              No stock payment upfront. Add a partner product, share your storefront, and keep the displayed earning when it sells.
            </p>
          </div>
          <span
            id="available-offer-count"
            class="w-fit rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-700 ring-1 ring-emerald-600/15"
          >
            {@offer_count} available
          </span>
        </div>

        <div id="earn-offers" phx-update="stream" class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          <div
            id="offers-empty"
            class="hidden only:block rounded-3xl border border-dashed border-slate-300 bg-slate-50 p-10 text-center md:col-span-2 xl:col-span-3"
          >
            <.icon name="hero-shopping-bag" class="mx-auto size-9 text-slate-300" />
            <p class="mt-3 text-sm font-semibold text-slate-700">No new products available</p>
            <p class="mt-1 text-xs text-slate-500">
              Connect with a supplier or check back when partners publish new offers.
            </p>
          </div>

          <article
            :for={{dom_id, offer} <- @streams.offers}
            id={dom_id}
            class="group overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm transition duration-200 hover:-translate-y-1 hover:border-emerald-200 hover:shadow-xl hover:shadow-emerald-950/5"
          >
            <div class="relative aspect-[16/10] overflow-hidden bg-gradient-to-br from-emerald-50 to-slate-100">
              <img
                :if={lead_image(offer)}
                src={lead_image(offer).url}
                alt={lead_image(offer).alt_text || offer.source_product.title}
                class="size-full object-cover transition duration-500 group-hover:scale-[1.03]"
                loading="lazy"
              />
              <div
                :if={!lead_image(offer)}
                class="flex size-full items-center justify-center text-emerald-200"
              >
                <.icon name="hero-photo" class="size-12" />
              </div>
              <span class="absolute left-3 top-3 rounded-full bg-slate-950/85 px-3 py-1 text-[11px] font-bold text-white backdrop-blur">
                No upfront stock
              </span>
            </div>
            <div class="p-5">
              <p class="text-xs font-medium text-slate-400">{offer.wholesaler_store.name}</p>
              <h3 class="mt-1 line-clamp-2 text-lg font-bold text-slate-900">
                {offer.source_product.title}
              </h3>
              <div class="mt-4 grid grid-cols-2 gap-3 rounded-2xl bg-slate-50 p-3">
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wide text-slate-400">Sell for</p>
                  <p class="mt-1 text-sm font-bold text-slate-800">{retail_range(offer)}</p>
                </div>
                <div class="border-l border-slate-200 pl-3">
                  <p class="text-[10px] font-bold uppercase tracking-wide text-emerald-600">
                    You earn
                  </p>
                  <p class="mt-1 text-sm font-bold text-emerald-700">{earning_range(offer)}</p>
                </div>
              </div>
              <button
                id={"import-offer-#{offer.id}"}
                phx-click="import_offer"
                phx-value-id={offer.id}
                class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-3 text-sm font-bold text-white shadow-sm transition hover:bg-emerald-700 active:scale-[0.98]"
              >
                <.icon name="hero-plus" class="size-4" /> Add to my store
              </button>
            </div>
          </article>
        </div>
      </section>

      <section id="earned-listings" aria-labelledby="earned-listings-heading" class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 id="earned-listings-heading" class="text-xl font-semibold text-slate-900">
              Added from partners
            </h2>
            <p class="mt-1 text-sm text-slate-500">
              These products behave like the rest of your catalog and fulfill through their supplier.
            </p>
          </div>
          <span
            id="listing-count"
            class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
          >
            {@listing_count}
          </span>
        </div>
        <div id="reseller-listings" phx-update="stream" class="grid gap-3 sm:grid-cols-2">
          <div
            id="listings-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center sm:col-span-2"
          >
            <p class="text-sm font-semibold text-slate-700">
              You have not added a partner product yet.
            </p>
          </div>
          <article
            :for={{dom_id, listing} <- @streams.listings}
            id={dom_id}
            class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
              <.icon name="hero-check" class="size-5" />
            </div>
            <div class="min-w-0 flex-1">
              <h3 class="truncate text-sm font-semibold text-slate-900">
                {listing.reseller_product.title}
              </h3>
              <p class="mt-0.5 text-xs capitalize text-slate-500">
                {listing.status} · Synced from partner
              </p>
            </div>
            <button
              id={"create-sales-kit-#{listing.id}"}
              phx-click="create_sales_kit"
              phx-value-id={listing.id}
              class="rounded-lg border border-emerald-200 px-3 py-2 text-xs font-bold text-emerald-700 transition hover:bg-emerald-50"
            >
              Sales kit
            </button>
            <.link
              navigate={~p"/admin/products/#{listing.reseller_product_id}/edit"}
              class="rounded-lg p-2 text-slate-400 transition hover:bg-slate-50 hover:text-slate-700"
              aria-label={"Edit #{listing.reseller_product.title}"}
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </.link>
          </article>
        </div>
      </section>

      <div
        id="earn-activation-grid"
        aria-labelledby="first-money-heading"
        class="grid gap-5 lg:grid-cols-[0.9fr_1.4fr]"
      >
        <section
          id="first-money-journey"
          class="rounded-3xl border border-emerald-200 bg-gradient-to-br from-emerald-50 to-white p-6 shadow-sm sm:p-7"
        >
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">
            First Money journey
          </span>
          <h2 id="first-money-heading" class="mt-2 text-2xl font-bold tracking-tight text-slate-950">
            Your path to the first fulfilled sale
          </h2>
          <p class="mt-2 text-sm leading-6 text-slate-600">
            Focus on one next action at a time. Makola updates this automatically from real activity.
          </p>

          <ol id="first-money-steps" class="mt-6 space-y-3">
            <li
              :for={
                step <- [
                  journey_step(@first_money, :connected, "Connect", "Agree with a supplier"),
                  journey_step(@first_money, :listed, "List", "Add one product to your store"),
                  journey_step(@first_money, :shared, "Share", "Send a tracked sales link"),
                  journey_step(@first_money, :sold, "Sell", "Receive a confirmed attributed order"),
                  journey_step(
                    @first_money,
                    :fulfilled,
                    "Fulfill",
                    "Complete delivery to the customer"
                  )
                ]
              }
              id={"first-money-step-#{step.key}"}
              data-complete={to_string(step.complete?)}
              class="flex items-start gap-3"
            >
              <span class={[
                "mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full ring-1 ring-inset",
                if(step.complete?,
                  do: "bg-emerald-600 text-white ring-emerald-600",
                  else: "bg-white text-slate-300 ring-slate-200"
                )
              ]}>
                <.icon
                  name={if(step.complete?, do: "hero-check", else: "hero-ellipsis-horizontal")}
                  class="size-4"
                />
              </span>
              <div>
                <p class={[
                  "text-sm font-bold",
                  if(step.complete?, do: "text-emerald-800", else: "text-slate-700")
                ]}>
                  {step.label}
                </p>
                <p class="text-xs text-slate-500">{step.description}</p>
              </div>
            </li>
          </ol>
        </section>

        <section
          id="sales-kit-panel"
          class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-7"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-600">
                Sales Kits
              </span>
              <h2 class="mt-2 text-xl font-bold text-slate-950">Ready-to-share product links</h2>
              <p class="mt-1 text-sm text-slate-500">
                Use the Sales kit button beside an imported product. Every link tracks genuine interest and confirmed orders.
              </p>
            </div>
            <div class="grid grid-cols-3 gap-2 text-center">
              <div class="rounded-xl bg-slate-50 px-3 py-2">
                <p id="sales-click-count" class="text-sm font-bold text-slate-900">
                  {@sales_click_count}
                </p>
                <p class="text-[10px] uppercase text-slate-400">Clicks</p>
              </div>
              <div class="rounded-xl bg-slate-50 px-3 py-2">
                <p id="sales-order-count" class="text-sm font-bold text-slate-900">
                  {@sales_order_count}
                </p>
                <p class="text-[10px] uppercase text-slate-400">Orders</p>
              </div>
              <div class="rounded-xl bg-emerald-50 px-3 py-2">
                <p id="sales-revenue" class="text-sm font-bold text-emerald-800">
                  {money(@sales_revenue)}
                </p>
                <p class="text-[10px] uppercase text-emerald-600">Sales</p>
              </div>
            </div>
          </div>

          <div id="sales-shares" phx-update="stream" class="mt-5 grid gap-3 sm:grid-cols-2">
            <div
              id="sales-shares-empty"
              class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-8 text-center sm:col-span-2"
            >
              <.icon name="hero-megaphone" class="mx-auto size-8 text-slate-300" />
              <p class="mt-2 text-sm font-semibold text-slate-700">Create your first Sales Kit</p>
              <p class="mt-1 text-xs text-slate-500">
                Choose an imported product above to generate channel-ready links.
              </p>
            </div>

            <article
              :for={{dom_id, share} <- @streams.sales_shares}
              id={dom_id}
              class="rounded-2xl border border-slate-200 p-4 transition hover:border-violet-200 hover:shadow-sm"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="flex min-w-0 items-center gap-3">
                  <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-violet-700">
                    <.icon name={channel_icon(share.channel)} class="size-4" />
                  </span>
                  <div class="min-w-0">
                    <p class="truncate text-sm font-bold text-slate-900">{share.product.title}</p>
                    <p class="text-xs text-slate-500">{channel_label(share.channel)}</p>
                  </div>
                </div>
                <span class="text-[10px] font-semibold text-slate-400">
                  {share.click_count} clicks · {share.order_count} orders
                </span>
              </div>

              <%= case share.channel do %>
                <% :whatsapp -> %>
                  <a
                    id={"share-whatsapp-#{share.id}"}
                    href={whatsapp_share_url(share)}
                    target="_blank"
                    rel="noopener"
                    phx-click="record_sales_share"
                    phx-value-id={share.id}
                    class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700"
                  >
                    <.icon name="hero-chat-bubble-left-right" class="size-4" /> Share on WhatsApp
                  </a>
                <% :facebook -> %>
                  <a
                    id={"share-facebook-#{share.id}"}
                    href={facebook_share_url(share)}
                    target="_blank"
                    rel="noopener"
                    phx-click="record_sales_share"
                    phx-value-id={share.id}
                    class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-blue-700"
                  >
                    <.icon name="hero-user-group" class="size-4" /> Share on Facebook
                  </a>
                <% :copy_link -> %>
                  <button
                    id={"copy-sales-link-#{share.id}"}
                    type="button"
                    phx-hook=".CopySalesLink"
                    phx-click="record_sales_share"
                    phx-value-id={share.id}
                    data-url={sales_share_url(share)}
                    class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-violet-700"
                  >
                    <.icon name="hero-link" class="size-4" /> Copy sales link
                  </button>
              <% end %>
            </article>
          </div>
        </section>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopySalesLink">
        export default {
          mounted() {
            this.el.addEventListener("click", () => navigator.clipboard.writeText(this.el.dataset.url))
          }
        }
      </script>

      <section id="supplier-inbox" aria-labelledby="supplier-inbox-heading" class="space-y-5">
        <div class="overflow-hidden rounded-3xl bg-gradient-to-br from-slate-950 to-slate-800 px-6 py-7 text-white shadow-lg sm:px-8">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <span class="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.18em] text-emerald-300">
                <.icon name="hero-inbox-stack" class="size-4" /> Supplier inbox
              </span>
              <h2 id="supplier-inbox-heading" class="mt-2 text-2xl font-bold tracking-tight">
                Orders for you to fulfill
              </h2>
              <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
                These orders were sold by connected Makola stores using your products. Ship directly to the customer, then use their private code as delivery proof.
              </p>
            </div>
            <span
              id="inbound-fulfillment-count"
              class="w-fit rounded-full bg-white/10 px-3 py-1.5 text-xs font-bold text-white ring-1 ring-white/15"
            >
              {@inbound_count} orders
            </span>
          </div>
        </div>

        <div id="inbound-fulfillments" phx-update="stream" class="space-y-4">
          <div
            id="inbound-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"
          >
            <.icon name="hero-truck" class="mx-auto size-9 text-slate-300" />
            <p class="mt-3 text-sm font-semibold text-slate-700">No partner orders need attention</p>
            <p class="mt-1 text-xs text-slate-500">
              New paid orders for your shared products will appear here.
            </p>
          </div>

          <article
            :for={{dom_id, fulfillment} <- @streams.inbound_fulfillments}
            id={dom_id}
            class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6"
          >
            <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <div class="flex flex-wrap items-center gap-2">
                  <h3 class="font-bold text-slate-900">Order {fulfillment.order.order_number}</h3>
                  <span class={[
                    "rounded-full px-2.5 py-1 text-[11px] font-bold capitalize",
                    fulfillment_status_classes(fulfillment.status)
                  ]}>
                    {fulfillment.status}
                  </span>
                </div>
                <p class="mt-1 text-xs text-slate-500">
                  Sold by {fulfillment.supplier.name} · Deliver to {customer_city(fulfillment.order)}
                </p>
              </div>
              <p class="text-xs font-semibold text-slate-400">
                {length(fulfillment.line_items)} item types
              </p>
            </div>

            <ul class="mt-4 divide-y divide-slate-100 rounded-xl bg-slate-50 px-4">
              <li
                :for={item <- fulfillment.line_items}
                class="flex items-center justify-between gap-4 py-3 text-sm"
              >
                <span class="font-medium text-slate-700">{item.product_title}</span>
                <span class="shrink-0 text-xs font-bold text-slate-500">× {item.quantity}</span>
              </li>
            </ul>

            <div class="mt-4 flex flex-wrap items-center gap-2">
              <button
                :if={fulfillment.status in [:pending, :notified]}
                id={"prepare-shipment-#{fulfillment.id}"}
                phx-click="select_inbound_shipping"
                phx-value-id={fulfillment.id}
                class="rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700 active:scale-[0.98]"
              >
                Mark shipped
              </button>
              <button
                :if={fulfillment.status == :shipped}
                id={"send-delivery-code-#{fulfillment.id}"}
                phx-click="request_delivery_code"
                phx-value-id={fulfillment.id}
                class="rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700 active:scale-[0.98]"
              >
                {if fulfillment.delivery_proof, do: "Send new code", else: "Send delivery code"}
              </button>
              <button
                :if={fulfillment.status == :shipped and fulfillment.delivery_proof}
                id={"enter-delivery-code-#{fulfillment.id}"}
                phx-click="enter_delivery_code"
                phx-value-id={fulfillment.id}
                class="rounded-xl border border-slate-200 px-4 py-2.5 text-xs font-bold text-slate-700 transition hover:bg-slate-50"
              >
                Enter customer code
              </button>
              <span
                :if={fulfillment.status == :delivered}
                class="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-700"
              >
                <.icon name="hero-check-circle" class="size-4" /> Customer confirmed delivery
              </span>
            </div>

            <.form
              :if={shipment_open?(fulfillment.id, @shipping_fulfillment_id)}
              for={@shipping_form}
              id={"ship-inbound-form-#{fulfillment.id}"}
              phx-submit="ship_inbound"
              class="mt-4 flex flex-col gap-3 rounded-xl border border-slate-200 bg-slate-50 p-4 sm:flex-row sm:items-end"
            >
              <div class="flex-1">
                <.input
                  field={@shipping_form[:tracking_number]}
                  type="text"
                  label="Tracking number"
                  placeholder="Optional courier reference"
                />
              </div>
              <div class="flex gap-2 pb-0.5">
                <button
                  type="submit"
                  class="rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white"
                >
                  Confirm shipment
                </button>
                <button
                  type="button"
                  phx-click="cancel_inbound_shipping"
                  class="rounded-xl px-3 py-2.5 text-xs font-bold text-slate-500"
                >
                  Cancel
                </button>
              </div>
            </.form>

            <.form
              :if={delivery_open?(fulfillment.id, @delivery_fulfillment_id)}
              for={@delivery_form}
              id={"verify-delivery-form-#{fulfillment.id}"}
              phx-submit="verify_delivery"
              class="mt-4 flex flex-col gap-3 rounded-xl border border-emerald-200 bg-emerald-50/60 p-4 sm:flex-row sm:items-end"
            >
              <div class="flex-1">
                <.input
                  field={@delivery_form[:code]}
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]{6}"
                  maxlength="6"
                  label="Customer's 6-digit code"
                  placeholder="000000"
                  required
                />
              </div>
              <button
                type="submit"
                class="rounded-xl bg-emerald-700 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-800"
              >
                Confirm delivery
              </button>
            </.form>
          </article>
        </div>
      </section>
    </div>
    """
  end
end
