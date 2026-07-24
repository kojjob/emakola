defmodule EmakolaWeb.Admin.SupplyOffersLive.Index do
  @moduledoc """
  The store's own supplier offers: status, per-status lifecycle actions,
  and the entry point to the offer form. All writes go through
  Emakola.Suppliers.Offers.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "My Offers", active_nav: :supply_offers)

    socket =
      if connected?(socket) do
        assign(socket, loading: false, offers: load_offers(socket))
      else
        assign(socket, loading: true, offers: [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("publish_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.publish/2, "Offer published — it is now live in the catalog.")
  end

  def handle_event("pause_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.pause/2, "Offer paused — hidden from the catalog.")
  end

  def handle_event("archive_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.archive/2, "Offer archived.")
  end

  def handle_event("unarchive_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.unarchive/2, "Offer restored to draft.")
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp lifecycle(socket, id, fun, success_message) do
    actor = socket.assigns.current_merchant

    with %{} = offer <- Enum.find(socket.assigns.offers, &(&1.id == id)),
         {:ok, _} <- fun.(actor, offer) do
      {:noreply,
       socket
       |> assign(offers: load_offers(socket))
       |> put_flash(:info, success_message)}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "That offer is not in your store.")}

      {:error, :invalid_offer_economics} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Fix the pricing first — every priced variant needs valid economics."
         )}

      {:error, :offer_requires_variants} ->
        {:noreply,
         put_flash(socket, :error, "Add at least one priced variant before publishing.")}

      {:error, :offer_requires_available_variant} ->
        {:noreply,
         put_flash(socket, :error, "The source product has no available stock to offer.")}

      {:error, :source_product_not_sellable} ->
        {:noreply,
         put_flash(socket, :error, "The source product must be active before publishing.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That change could not be applied right now.")}
    end
  end

  defp load_offers(socket) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, offers} <- Offers.list_owned(socket.assigns.current_merchant, store_id) do
      offers
    else
      _ -> []
    end
  end

  defp status_label(:draft), do: "Draft"
  defp status_label(:published), do: "Published"
  defp status_label(:paused), do: "Paused"
  defp status_label(:archived), do: "Archived"

  defp status_class(:draft), do: "bg-slate-100 text-slate-600"
  defp status_class(:published), do: "bg-emerald-50 text-emerald-700"
  defp status_class(:paused), do: "bg-amber-50 text-amber-700"
  defp status_class(:archived), do: "bg-slate-100 text-slate-400"

  defp first_image_url(offer) do
    case offer.source_product.images do
      [_ | _] = images ->
        img = images |> Enum.sort_by(&Map.get(&1, :position, 0)) |> List.first()
        Map.get(img, :thumbnail_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  defp price_summary(offer) do
    case offer.offer_variants do
      [] ->
        "No priced variants"

      variants ->
        prices = Enum.map(variants, & &1.supplier_price)
        {min, max} = {Enum.min(prices), Enum.max(prices)}

        if min == max,
          do: "#{format_price(min)} wholesale",
          else: "#{format_price(min)} – #{format_price(max)} wholesale"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-6 pt-2">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">My Offers</h1>
          <p class="text-sm text-slate-500 mt-1">
            Products you supply to other stores on the network
          </p>
        </div>
        <.link
          navigate={~p"/admin/supply/offers/new"}
          class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
        >
          New offer
        </.link>
      </div>

      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading…</div>

      <div
        :if={!@loading and @offers == []}
        class="rounded-2xl border border-dashed border-slate-300 py-16 text-center"
      >
        <p class="text-sm font-medium text-slate-700">You have no supplier offers yet.</p>
        <p class="text-xs text-slate-500 mt-1 max-w-md mx-auto">
          Publish an offer and any merchant on the network can find it in the
          <.link navigate={~p"/admin/supply/catalog"} class="text-emerald-700">
            Browse Suppliers
          </.link>
          and stock your product in their store.
        </p>
      </div>

      <div :if={!@loading} class="space-y-3">
        <div
          :for={offer <- @offers}
          class="rounded-2xl border border-slate-200 bg-white p-4 flex flex-wrap items-center gap-4"
        >
          <div class="shrink-0 w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center overflow-hidden">
            <img
              :if={first_image_url(offer)}
              src={first_image_url(offer)}
              alt={offer.source_product.title}
              class="w-full h-full object-cover"
            />
            <.icon :if={!first_image_url(offer)} name="hero-photo" class="size-5 text-slate-400" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="font-semibold text-sm text-slate-900 truncate">
              {offer.source_product.title}
            </p>
            <p class="text-xs text-slate-500 mt-0.5">
              {length(offer.offer_variants)} variant(s) · {price_summary(offer)} · {if offer.earning_model ==
                                                                                         :markup,
                                                                                       do: "Markup",
                                                                                       else:
                                                                                         "Fixed commission"}
            </p>
          </div>
          <span class={[
            "text-[10px] font-semibold uppercase tracking-wide rounded-full px-2 py-0.5",
            status_class(offer.status)
          ]}>
            {status_label(offer.status)}
          </span>
          <div class="flex items-center gap-2">
            <.link
              :if={offer.status in [:draft, :paused]}
              navigate={~p"/admin/supply/offers/#{offer.id}/edit"}
              class="text-sm font-medium text-slate-600 hover:text-slate-900"
            >
              Edit
            </.link>
            <.link
              :if={offer.status == :published}
              navigate={~p"/admin/supply/offers/#{offer.id}/edit"}
              class="text-sm font-medium text-slate-600 hover:text-slate-900"
            >
              Edit terms
            </.link>
            <button
              :if={offer.status in [:draft, :paused]}
              phx-click="publish_offer"
              phx-value-id={offer.id}
              class="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
            >
              {if offer.status == :paused, do: "Republish", else: "Publish"}
            </button>
            <button
              :if={offer.status == :published}
              phx-click="pause_offer"
              phx-value-id={offer.id}
              class="text-sm font-semibold text-amber-700 hover:text-amber-800"
            >
              Pause
            </button>
            <button
              :if={offer.status != :archived}
              phx-click="archive_offer"
              phx-value-id={offer.id}
              data-confirm="Archiving is permanent for this offer — you can restore it later from the archived state. Continue?"
              class="text-sm font-medium text-slate-400 hover:text-slate-600"
            >
              Archive
            </button>
            <button
              :if={offer.status == :archived}
              phx-click="unarchive_offer"
              phx-value-id={offer.id}
              class="text-sm font-medium text-slate-600 hover:text-slate-900"
            >
              Unarchive
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
