defmodule EmakolaWeb.Storefront.PayLinkLive do
  @moduledoc """
  Express checkout for a shared pay link (`/pay/:code`, apex host).

  Loads link + store by code (no ResolveStore — the link IS the tenant
  pointer). Renders: usable link → item + buyer form; anything else → a
  friendly inactive/sold-out state. Payment initiation mirrors
  `CheckoutLive`; the callback lands on the store's normal order
  confirmation page.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  alias Emakola.Orders.PayLink
  alias Emakola.Payments.Protection
  alias EmakolaWeb.AddressComponents
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    case Emakola.Orders.get_pay_link_by_code(code, authorize?: false) do
      {:ok, link} ->
        store = Ash.get!(Emakola.Stores.Store, link.store_id, authorize?: false)
        variant = load_variant(link)
        quantity = initial_quantity(link, variant)

        if connected?(socket) do
          link
          |> Ash.Changeset.for_update(:increment_opened, %{})
          |> Ash.update(authorize?: false)
        end

        {:ok,
         socket
         |> assign(:link, link)
         |> assign(:store, store)
         |> assign(:variant, variant)
         |> assign(:state, page_state(link, store, variant))
         |> assign(:quantity, quantity)
         |> assign(:processing, false)
         |> assign(:buyer, empty_buyer())
         |> assign(:form_errors, %{})
         |> assign(:page_title, store.name)
         # The storefront layout renders the search overlay whenever @store is
         # assigned (true in all four of this LiveView's states), so these
         # need real defaults — matching StoreLive's mount exactly — or the
         # component's `assigns[:key] || default` fallbacks paper over it
         # until the buyer actually types, at which point handle_event/3
         # would have nothing to match without the handlers below.
         |> assign(:search_overlay_query, "")
         |> assign(:search_overlay_results, [])
         |> assign(:search_overlay_total, 0)
         |> assign(:searching, false)
         |> assign_pay_forms()}

      {:error, _} ->
        raise Ash.Error.Query.NotFound
    end
  end

  # :ok | :inactive | :store_unavailable | :sold_out
  defp page_state(link, store, variant) do
    cond do
      not Emakola.Stores.Store.live?(store) -> :store_unavailable
      PayLink.usable?(link) != :ok -> :inactive
      link.type == :catalog and out_of_stock?(link, variant) -> :sold_out
      true -> :ok
    end
  end

  defp load_variant(%PayLink{type: :catalog, variant_id: variant_id})
       when is_binary(variant_id) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(id == ^variant_id)
    |> Ash.Query.load(:product)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, variant} -> variant
      _ -> nil
    end
  end

  defp load_variant(%PayLink{}), do: nil

  # A catalog link whose variant can't load (deleted/archived after the link
  # was shared) has nothing sellable behind it — treat that as sold out, not
  # as "in stock." Without this, `page_state/3` would fall through to `:ok`
  # with `@variant` nil, rendering a bare "Pay GH₵0" button instead of the
  # sold-out message.
  defp out_of_stock?(_link, nil), do: true

  defp out_of_stock?(link, variant),
    do: not Emakola.Catalog.Variant.in_stock?(variant, link.quantity)

  # The admin's WhatsApp quote is price × link.quantity (see
  # PayLinkLive.Index.amount_for/2) — a catalog link created for a bulk
  # order (say, quantity: 5) must show that same total on first render, not
  # a ×1 amount the buyer would have to notice and correct themselves.
  # Clamped into `quantity_options/2`'s own range so a link.quantity that
  # has since outgrown current stock doesn't preselect an unbuyable value.
  defp initial_quantity(%PayLink{type: :catalog, quantity: qty}, variant) do
    range = quantity_options(variant, qty)
    qty |> max(range.first) |> min(range.last)
  end

  defp initial_quantity(%PayLink{}, _variant), do: 1

  # -- Event Handlers -------------------------------------------------------

  @impl true
  def handle_event("validate", %{"buyer" => buyer_params}, socket) do
    {:noreply,
     socket
     |> assign(:buyer, Map.merge(socket.assigns.buyer, buyer_params))
     |> assign_pay_forms()}
  end

  @impl true
  def handle_event("set_quantity", %{"quantity" => quantity_str}, socket) do
    {:noreply,
     socket
     |> assign(:quantity, parse_quantity(quantity_str))
     |> assign_pay_forms()}
  end

  # The storefront layout mounts `EmakolaWeb.SearchComponents.search_overlay`
  # unconditionally whenever `@store` is assigned — true in every state this
  # LiveView renders. Its input (`phx-keyup="search_overlay"`) and its
  # close affordances (backdrop click / Escape / close button, all wired to
  # `SearchComponents.hide_search/0`, which pushes `"close_search"`) need
  # handlers here too, or a buyer who taps search mid-checkout kills the
  # socket. Mirrors `StoreLive`'s handlers and private helpers exactly.
  @impl true
  def handle_event("search_overlay", %{"value" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:search_overlay_query, "")
       |> assign(:search_overlay_results, [])
       |> assign(:search_overlay_total, 0)
       |> assign(:searching, false)}
    else
      results = search_overlay_products(socket.assigns.store.id, query)
      total = count_search_results(socket.assigns.store.id, query)

      {:noreply,
       socket
       |> assign(:search_overlay_query, query)
       |> assign(:search_overlay_results, Enum.take(results, 6))
       |> assign(:search_overlay_total, total)
       |> assign(:searching, false)}
    end
  end

  @impl true
  def handle_event("close_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_overlay_query, "")
     |> assign(:search_overlay_results, [])
     |> assign(:search_overlay_total, 0)
     |> assign(:searching, false)}
  end

  @impl true
  def handle_event("pay", %{"buyer" => buyer}, socket) do
    %{link: link, store: store, variant: variant} = socket.assigns

    cond do
      is_nil(presence(buyer["phone"])) ->
        {:noreply,
         assign(socket, form_errors: %{base: "Please enter a phone number."}, processing: false)}

      not valid_phone?(buyer["phone"]) ->
        {:noreply,
         assign(socket, form_errors: %{base: "Enter a valid phone number"}, processing: false)}

      not Emakola.GhanaDigitalAddress.valid?(buyer["digital_address"]) ->
        {:noreply,
         assign(socket,
           form_errors: %{base: "Check the digital address — it looks like GA-183-8164"},
           processing: false
         )}

      true ->
        # Re-fetch by code rather than trusting the struct captured at mount —
        # the merchant may have cancelled the link (or a rival buyer consumed
        # it) in the time between page load and this submit. Checking
        # `usable?` on a stale struct would let the buyer reach the gateway's
        # hosted page on a link that's no longer supposed to be payable.
        case Emakola.Orders.get_pay_link_by_code(link.code, authorize?: false) do
          {:ok, fresh_link} ->
            case PayLink.usable?(fresh_link) do
              :ok ->
                case create_order(fresh_link, store, buyer, socket.assigns.quantity) do
                  {:ok, order} ->
                    initiate_payment(socket, store, order)

                  {:error, reason} ->
                    {:noreply,
                     assign(socket,
                       form_errors: %{base: friendly_error(reason)},
                       processing: false
                     )}
                end

              {:error, _reason} ->
                {:noreply, refresh_inactive_state(socket, fresh_link, store, variant)}
            end

          {:error, _reason} ->
            {:noreply, refresh_inactive_state(socket, link, store, variant)}
        end
    end
  end

  # Validates the RAW input's digit shape before any normalization —
  # PhoneAuth.normalize/1 pads any digit string with no leading 0/233/234
  # with a "+233" prefix, so counting digits *after* normalization lets a
  # short garbage number (e.g. "555555") reach 9+ digits and pass. Accepts a
  # local 0-prefixed number (0XXXXXXXXX) or E.164 without the leading "+"
  # (233XXXXXXXXX), in any punctuation/spacing.
  defp valid_phone?(raw) when is_binary(raw) do
    digits = String.replace(raw, ~r/\D/, "")
    Regex.match?(~r/^0\d{9}$/, digits) or Regex.match?(~r/^233\d{9}$/, digits)
  end

  defp valid_phone?(_), do: false

  # Mirrors mount's `page_state/3` so a link that turned unusable between
  # page load and submit renders the same inactive/unavailable/sold-out
  # state mount would have rendered — the form disappears instead of just
  # showing a dismissable error the buyer could retry against.
  defp refresh_inactive_state(socket, link, store, variant) do
    socket
    |> assign(:link, link)
    |> assign(:state, page_state(link, store, variant))
    |> assign(:processing, false)
  end

  defp parse_quantity(str) do
    case Integer.parse(str) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  # -- Search overlay helpers (copied from StoreLive) ----------------------

  defp search_overlay_products(store_id, query) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> Ash.Query.limit(10)
    |> Ash.read!(authorize?: false)
  end

  defp count_search_results(store_id, query) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp create_order(%PayLink{type: :custom} = link, store, buyer, _qty) do
    Emakola.Orders.CheckoutService.checkout_custom!(
      store.id,
      %{title: link.title, unit_price: link.amount},
      customer_name: buyer["name"],
      customer_phone: buyer["phone"],
      customer_email:
        presence(buyer["email"]) ||
          Emakola.Orders.CheckoutService.phone_placeholder_email(buyer["phone"]),
      shipping_address: shipping_address(link, buyer),
      pay_link_id: link.id
    )
  end

  defp create_order(%PayLink{type: :catalog} = link, store, buyer, qty) do
    Emakola.Orders.CheckoutService.checkout!(
      store.id,
      [%{variant_id: link.variant_id, quantity: qty}],
      customer_email:
        presence(buyer["email"]) ||
          Emakola.Orders.CheckoutService.phone_placeholder_email(buyer["phone"]),
      customer_name: buyer["name"],
      customer_phone: buyer["phone"],
      shipping_address: shipping_address(link, buyer),
      pay_link_id: link.id
    )
  end

  defp shipping_address(%PayLink{collect_delivery: false}, _buyer), do: nil

  defp shipping_address(%PayLink{collect_delivery: true}, buyer) do
    %{"name" => buyer["name"], "phone" => buyer["phone"], "address" => buyer["address"]}
    |> put_digital_address(buyer["digital_address"])
    |> put_landmark(buyer["landmark"])
  end

  defp put_digital_address(map, raw) do
    case Emakola.GhanaDigitalAddress.normalize(raw) do
      blank when blank in [nil, ""] -> map
      normalized -> Map.put(map, "digital_address", normalized)
    end
  end

  # Truncated (not rejected) at 200 chars — landmark is best-effort rider
  # help on a buyer checkout flow, which must never block on it. This is the
  # deliberate opposite of the Address/Store resources' landmark attribute,
  # which REJECTS over 200 chars via `constraints(max_length: 200)`: those
  # are merchant/profile-data writes, where surfacing a validation error is
  # the right call.
  defp put_landmark(map, raw) do
    case String.trim(raw || "") do
      "" -> map
      landmark -> Map.put(map, "landmark", String.slice(landmark, 0, 200))
    end
  end

  defp presence(nil), do: nil
  defp presence(value), do: if(String.trim(value) == "", do: nil, else: value)

  defp friendly_error(:expired), do: "This payment link has expired."
  defp friendly_error(:cancelled), do: "This payment link is no longer active."
  defp friendly_error(:consumed), do: "This payment link has already been used."
  defp friendly_error(:insufficient_stock), do: "Sorry, this item just sold out."
  defp friendly_error(:variant_not_found), do: "Sorry, this item is no longer available."
  defp friendly_error(:product_unavailable), do: "Sorry, this item is no longer available."
  defp friendly_error(_reason), do: "We couldn't process that — please try again."

  # -- Payment initiation (mirrors CheckoutLive:470-530) -------------------

  # Ship-dark SplitPay pilot: when the client is configured, pay-link
  # charges route through SplitPay (order confirmation then arrives via
  # /webhooks/splitpay); otherwise the existing gateway path runs
  # unchanged.
  defp initiate_payment(socket, store, order) do
    if Emakola.SplitPay.Client.enabled?() do
      initiate_splitpay_payment(socket, store, order)
    else
      initiate_gateway_payment(socket, store, order)
    end
  end

  defp initiate_splitpay_payment(socket, store, order) do
    case Emakola.SplitPay.Checkout.initiate(order, store,
           customer_email: customer_email(order, store)
         ) do
      {:ok, %{checkout_url: url}} ->
        {:noreply, socket |> assign(:processing, false) |> redirect(external: url)}

      {:error, reason} ->
        Logger.error(
          "[pay_link] SplitPay initiation failed for order #{order.order_number}: #{inspect(reason)}"
        )

        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:form_errors, %{
           base:
             "We couldn't start your payment just now. Your order #{order.order_number} is saved — please try again."
         })}
    end
  end

  defp initiate_gateway_payment(socket, store, order) do
    gateway = Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

    # Resolve how the charge is split at the gateway — same trustless
    # dropship/platform-fee settlement every other order gets.
    settlement = Emakola.Payments.OrderSettlement.prepare(order.id, store.id)

    params =
      %{
        amount: order.total,
        email: customer_email(order, store),
        currency: store.currency || "GHS",
        order_id: order.id,
        store_id: store.id,
        order_reference: order.order_number,
        callback_url: confirmation_url(store, order),
        return_url: confirmation_url(store, order),
        # Deliberately no `channel` here (unlike CheckoutLive, which maps its
        # payment-method picker to a single Paystack channel): this page has
        # no method picker, so restricting to one channel would hide MoMo —
        # the primary rail for this market — on the gateway's hosted page.
        # Omitting the key entirely lets the gateway offer every channel
        # enabled on the merchant's account (confirmed against this repo's
        # own `Gateways.Paystack.initiate_payment/1`, which never reads
        # `params[:channel]` when building the request body anyway).
        metadata: %{payment_method: "pay_link"}
      }
      |> maybe_attach_split(settlement)

    case gateway.initiate_payment(params) do
      {:ok, %{reference: reference} = resp} ->
        case Emakola.Payments.OrderSettlement.persist_payment(
               Map.merge(
                 %{
                   store_id: store.id,
                   order_id: order.id,
                   amount: order.total,
                   currency: store.currency || "GHS",
                   gateway: :paystack,
                   gateway_reference: reference,
                   metadata: %{payment_method: "pay_link"},
                   split_mode: split_mode(settlement)
                 },
                 payout_hold_attrs(settlement)
               ),
               settlement
             ) do
          {:ok, _payment} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "[pay_link] failed to create payment record for order #{order.order_number}: #{inspect(reason)}"
            )
        end

        url = Map.get(resp, :authorization_url, "")

        if url != "" do
          {:noreply, socket |> assign(:processing, false) |> redirect(external: url)}
        else
          {:noreply,
           socket |> assign(:processing, false) |> redirect(to: confirmation_path(store, order))}
        end

      {:error, reason} ->
        release_recovery_reservations(settlement)

        Logger.error(
          "[pay_link] payment initiation failed for order #{order.order_number}: #{inspect(reason)}"
        )

        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:form_errors, %{
           base:
             "We couldn't start your payment just now. Your order #{order.order_number} is saved — please try again."
         })}
    end
  end

  defp confirmation_url(store, order),
    do: "#{EmakolaWeb.Endpoint.url()}#{confirmation_path(store, order)}"

  defp confirmation_path(store, order),
    do: "/s/#{store.slug}/orders/#{order.order_number}/confirmation"

  defp customer_email(%{customer_id: nil}, store), do: fallback_email(store)

  defp customer_email(order, store) do
    case Ash.get(Emakola.Customers.Customer, order.customer_id, authorize?: false) do
      {:ok, %{email: email}} when not is_nil(email) -> to_string(email)
      _ -> fallback_email(store)
    end
  end

  defp fallback_email(store),
    do: Map.get(store, :contact_email) || "checkout+#{store.slug}@makola.io"

  # -- Settlement split helpers (copied from CheckoutLive) -----------------

  defp maybe_attach_split(params, {:split, %{shares: shares}}),
    do: Map.put(params, :split, shares)

  defp maybe_attach_split(params, {:no_split, _reason}), do: params
  defp maybe_attach_split(params, {:hold, _}), do: params

  defp split_mode({:split, %{mode: mode}}), do: mode
  defp split_mode({:no_split, _}), do: :none
  defp split_mode({:hold, _}), do: :none

  # TC-2 Buyer Protection: a hold settles with NO merchant gateway share — the
  # payment is flagged so PayoutService (Task 5+) excludes it until the hold
  # releases (same literal pattern as GroupBuys/ProtectedPreorders escrow).
  defp payout_hold_attrs({:hold, :buyer_protection}),
    do: %{payout_held: true, payout_hold_reason: "buyer_protection"}

  defp payout_hold_attrs(_settlement), do: %{}

  defp release_recovery_reservations({:split, %{allocations: allocations}}),
    do: Emakola.Payments.OrderSettlement.release_recovery_reservations!(allocations)

  defp release_recovery_reservations({:no_split, _}), do: :ok
  defp release_recovery_reservations({:hold, _}), do: :ok

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(%{state: :store_unavailable} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">This store isn't available right now.</p>
    </div>
    """
  end

  def render(%{state: :inactive} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">
        This payment link is no longer active — contact the seller for a new link.
      </p>
    </div>
    """
  end

  def render(%{state: :sold_out} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">This item just sold out — contact the seller.</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-8 sm:py-12">
      <p class="text-sm font-medium text-[#94A3B8]">Pay {@store.name}</p>

      <div
        :if={@link.type == :catalog and @variant}
        class="mt-2 rounded-2xl border border-[#E2E8F0] bg-white p-4"
      >
        <h1 class="text-base font-semibold text-slate-900">{@variant.product.title}</h1>
        <p class="mt-1 text-lg font-bold text-slate-900">
          {Currency.format_price(@variant.price, @store.currency || "GHS")}
        </p>
      </div>

      <div :if={@link.type == :custom} class="mt-2 rounded-2xl border border-[#E2E8F0] bg-white p-4">
        <h1 class="text-base font-semibold text-slate-900">{@link.title}</h1>
        <p class="mt-1 text-lg font-bold text-slate-900">
          {Currency.format_price(@link.amount, @store.currency || "GHS")}
        </p>
      </div>

      <%!-- Buyer Protection Badge (TC-2) --%>
      <div
        :if={Protection.applies?(@store, @link) and not dropship_variant?(@variant)}
        id="buyer-protection-badge"
        class="mt-4 flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3.5 text-xs text-emerald-800"
      >
        <span aria-hidden="true">🛡</span>
        <span>Protected by Makola — payment held until you confirm delivery.</span>
      </div>

      <p :if={@form_errors[:base]} class="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
        {@form_errors.base}
      </p>

      <.form
        for={@buyer_form}
        id="pay-link-form"
        phx-submit="pay"
        phx-change="validate"
        class="mt-6 space-y-4"
      >
        <div :if={@link.type == :catalog and @variant}>
          <label class="block text-sm font-medium text-slate-700" for="pay-link-quantity">
            Quantity
          </label>
          <.input
            field={@quantity_form[:quantity]}
            type="select"
            id="pay-link-quantity"
            options={Enum.map(quantity_options(@variant, @link.quantity), &{to_string(&1), &1})}
            phx-change="set_quantity"
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="pay-link-name">
            Full name
          </label>
          <.input
            field={@buyer_form[:name]}
            type="text"
            id="pay-link-name"
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="pay-link-phone">
            Phone number
          </label>
          <.input
            field={@buyer_form[:phone]}
            type="tel"
            id="pay-link-phone"
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="pay-link-email">
            Email (optional)
          </label>
          <.input
            field={@buyer_form[:email]}
            type="email"
            id="pay-link-email"
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div :if={@link.collect_delivery}>
          <label class="block text-sm font-medium text-slate-700" for="pay-link-address">
            Delivery address
          </label>
          <.input
            field={@buyer_form[:address]}
            type="textarea"
            id="pay-link-address"
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <AddressComponents.gh_address_fields
          :if={@link.collect_delivery}
          digital_address={@buyer["digital_address"]}
          landmark={@buyer["landmark"]}
          field_prefix="buyer"
        />

        <button
          type="submit"
          phx-disable-with="Processing..."
          disabled={@processing}
          class="w-full rounded-lg bg-store-accent px-4 py-3 text-sm font-semibold text-white disabled:opacity-60"
        >
          Pay {Currency.format_price(pay_amount(assigns), @store.currency || "GHS")}
        </button>
      </.form>
    </div>
    """
  end

  defp pay_amount(%{link: %PayLink{type: :custom, amount: amount}}), do: amount

  defp pay_amount(%{link: %PayLink{type: :catalog}, variant: variant, quantity: qty})
       when not is_nil(variant),
       do: variant.price * qty

  defp pay_amount(_assigns), do: 0

  # TC-2 Buyer Protection: `Protection.applies?/2` is a store/link-level
  # predicate — it doesn't know this catalog link's item is dropship-sourced.
  # A pay link CAN point at a dropship variant (nothing stops one being
  # created for it); `CheckoutService.checkout!/3` copies `variant.supplier_id`
  # onto the fulfillment, and `DropshipSettlement` then routes the charge
  # through the dropship split — bypassing protection entirely, so no hold is
  # ever created (mirrors the same dropship-wins rule the checkout page's
  # badge already accounts for in `Emakola.Themes.DefaultRenderers.Checkout`).
  # Custom links have no `@variant` (nil), so this is a no-op for them.
  defp dropship_variant?(%{supplier_id: supplier_id}), do: not is_nil(supplier_id)
  defp dropship_variant?(_variant), do: false

  # Upper bound is normally 10, but a link.quantity above that (a bulk deal)
  # must still be selectable — the buyer shouldn't be forced down to a lower
  # quantity than the merchant actually negotiated for.
  defp quantity_options(%{track_inventory: true, stock_quantity: stock}, link_quantity)
       when stock > 0,
       do: 1..min(stock, max(10, link_quantity))

  defp quantity_options(_variant, link_quantity), do: 1..max(10, link_quantity)

  defp empty_buyer do
    %{
      "name" => "",
      "phone" => "",
      "email" => "",
      "address" => "",
      "digital_address" => "",
      "landmark" => ""
    }
  end

  defp assign_pay_forms(socket) do
    assign(socket,
      buyer_form: to_form(socket.assigns.buyer, as: :buyer),
      quantity_form: to_form(%{"quantity" => socket.assigns.quantity})
    )
  end
end
