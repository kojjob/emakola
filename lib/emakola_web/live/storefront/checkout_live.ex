defmodule EmakolaWeb.Storefront.CheckoutLive do
  @moduledoc """
  Checkout page — accordion multi-step checkout flow with coupon support
  and rich MoMo waiting state.

  Steps:
    1. Contact & Delivery
    2. Payment Method
    3. Review & Pay
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  require Ash.Query
  require Logger

  import EmakolaWeb.Storefront.Path

  alias Emakola.Cart.CartStore
  alias Emakola.Orders.CheckoutService

  @payment_poll_interval_ms 3_000
  @payment_poll_max_attempts 60

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    cart_session_id = session["cart_session_id"]

    cart =
      if connected?(socket) && cart_session_id,
        do: CartStore.get_cart(cart_session_id, store.id),
        else: []

    cart_total =
      Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)

    cart_count = Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)

    cart_weight_grams = cart_weight_grams(cart, store.id)
    dispatch_variants = dispatch_variants(cart, store.id)

    categories =
      try do
        Emakola.Catalog.list_root_categories!(store.id)
      rescue
        exception ->
          Logger.error(
            "[checkout_live] mount loading root categories raised: #{Exception.message(exception)}"
          )

          []
      end

    # UTM attribution captured by EmakolaWeb.Plugs.UtmCapture during the
    # customer's browse → checkout journey. Persisted onto the order at
    # creation so merchant analytics can attribute revenue by source.
    utm_attribution = session["utm_attribution"] || %{}

    sales_team_economics =
      case Emakola.Suppliers.SalesTeams.public_economics(
             utm_attribution["sales_team_id"],
             store.id
           ) do
        {:ok, economics} -> economics
        _ -> nil
      end

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart, cart)
     |> assign(:cart_count, cart_count)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_weight_grams, cart_weight_grams)
     |> assign(:dispatch_variants, dispatch_variants)
     |> assign(:utm_attribution, utm_attribution)
     |> assign(:sales_team_economics, sales_team_economics)
     |> assign(:step, 1)
     |> assign(:payment_method, "momo")
     |> assign(:phone, "")
     |> assign(:email, "")
     |> assign(:fullname, "")
     |> assign(:address, "")
     |> assign(:region, "greater_accra")
     |> assign(:notes, "")
     |> assign(:digital_address, "")
     |> assign(:landmark, "")
     |> assign(:processing, false)
     |> assign(:order, nil)
     |> assign(:checkout_error, nil)
     |> assign(:payment_status, nil)
     |> assign(:poll_attempts, 0)
     |> assign(:gateway_reference, nil)
     |> assign(:coupon_code, "")
     |> assign(:coupon, nil)
     |> assign(:discount_amount, 0)
     |> assign(:coupon_error, nil)
     |> assign(:show_mobile_summary, false)
     |> assign(:form_errors, %{})
     |> assign(:timer_seconds, 180)
     |> assign(:page_title, "Checkout - #{store.name}")
     # Resolve the default region's fee and estimate from the store's own
     # delivery zone up front. `delivery_fee` used to be hardcoded to 1500 at
     # mount and only corrected once the customer touched the form, so the first
     # thing a shopper read was a fee that had nothing to do with this store.
     |> update_delivery_fee()
     |> update_dispatch_fees()}
  end

  # -- Event Handlers -------------------------------------------------------

  @impl true
  def handle_event("select_payment", %{"method" => method}, socket),
    do: {:noreply, assign(socket, :payment_method, method)}

  @impl true
  def handle_event("go_to_step", %{"step" => step_str}, socket),
    do: {:noreply, assign(socket, :step, String.to_integer(step_str))}

  @impl true
  def handle_event("toggle_mobile_summary", _params, socket),
    do: {:noreply, assign(socket, :show_mobile_summary, !socket.assigns.show_mobile_summary)}

  @impl true
  def handle_event("update_details", params, socket) do
    {:noreply,
     socket
     |> assign(:phone, Map.get(params, "phone", socket.assigns.phone))
     |> assign(:email, Map.get(params, "email", socket.assigns.email))
     |> assign(:fullname, Map.get(params, "fullname", socket.assigns.fullname))
     |> assign(:address, Map.get(params, "address", socket.assigns.address))
     |> assign(:region, Map.get(params, "region", socket.assigns.region))
     |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
     |> assign(
       :digital_address,
       Map.get(params, "digital_address", socket.assigns.digital_address)
     )
     |> assign(:landmark, Map.get(params, "landmark", socket.assigns.landmark))
     |> assign(:coupon_code, Map.get(params, "coupon_code", socket.assigns.coupon_code))
     |> assign(:form_errors, %{})
     |> update_delivery_fee()
     |> update_dispatch_fees()}
  end

  @impl true
  def handle_event("submit_details", params, socket) do
    socket =
      socket
      |> assign(:phone, Map.get(params, "phone", ""))
      |> assign(:email, Map.get(params, "email", ""))
      |> assign(:fullname, Map.get(params, "fullname", ""))
      |> assign(:address, Map.get(params, "address", ""))
      |> assign(:region, Map.get(params, "region", "greater_accra"))
      |> assign(:notes, Map.get(params, "notes", ""))
      |> update_delivery_fee()
      |> update_dispatch_fees()

    errors = validate_contact_fields(socket.assigns)

    if errors == %{} do
      {:noreply, socket |> assign(:form_errors, %{}) |> assign(:step, 2)}
    else
      {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  @impl true
  def handle_event("apply_coupon", %{"coupon_code" => code}, socket) do
    variant_ids = Enum.map(socket.assigns.cart, & &1.variant_id)

    result =
      if Emakola.Suppliers.NetworkCheckoutEligibility.network_items?(
           socket.assigns.store.id,
           variant_ids
         ) do
        {:error, :network_coupon_not_allowed}
      else
        CheckoutService.validate_coupon(
          socket.assigns.store.id,
          code,
          socket.assigns.cart_total
        )
      end

    case result do
      {:ok, coupon} ->
        discount =
          CheckoutService.calculate_discount(
            coupon,
            socket.assigns.cart_total,
            socket.assigns.delivery_fee
          )

        {:noreply,
         socket
         |> assign(
           coupon: coupon,
           coupon_code: code,
           discount_amount: discount,
           coupon_error: nil
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(
           coupon_error: coupon_error_message(reason),
           coupon: nil,
           discount_amount: 0
         )}
    end
  end

  @impl true
  def handle_event("remove_coupon", _params, socket) do
    {:noreply,
     socket |> assign(coupon: nil, coupon_code: "", discount_amount: 0, coupon_error: nil)}
  end

  @impl true
  def handle_event("place_order", params, socket) do
    # Update fields from form params
    socket =
      socket
      |> assign(:phone, Map.get(params, "phone", socket.assigns.phone))
      |> assign(:email, Map.get(params, "email", socket.assigns.email))
      |> assign(:fullname, Map.get(params, "fullname", socket.assigns.fullname))
      |> assign(:address, Map.get(params, "address", socket.assigns.address))
      |> assign(:region, Map.get(params, "region", socket.assigns.region))
      |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
      |> assign(
        :digital_address,
        Map.get(params, "digital_address", socket.assigns.digital_address)
      )
      |> assign(:landmark, Map.get(params, "landmark", socket.assigns.landmark))
      |> update_delivery_fee()
      |> update_dispatch_fees()

    errors = validate_contact_fields(socket.assigns)

    cond do
      errors != %{} ->
        {:noreply, assign(socket, :form_errors, errors)}

      socket.assigns.cart == [] ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Your cart is empty -- please add items before checking out")}

      true ->
        socket = assign(socket, processing: true, form_errors: %{})

        case create_order(socket) do
          {:ok, order} ->
            socket = assign(socket, :order, order)
            handle_payment(socket, order)

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> put_flash(:error, checkout_error_message(reason))}
        end
    end
  end

  @impl true
  def handle_event("retry_payment", _params, socket) do
    if socket.assigns.order do
      handle_payment(
        assign(socket, processing: true, checkout_error: nil, timer_seconds: 180),
        socket.assigns.order
      )
    else
      {:noreply, put_flash(socket, :error, "No order to retry payment for")}
    end
  end

  # -- Info Handlers --------------------------------------------------------

  @impl true
  def handle_info(:poll_payment_status, socket) do
    order = socket.assigns.order
    poll_attempts = socket.assigns.poll_attempts

    if poll_attempts >= @payment_poll_max_attempts do
      {:noreply,
       socket
       |> assign(:processing, false)
       |> assign(:payment_status, :timeout)
       |> put_flash(:error, "Payment verification timed out.")}
    else
      case verify_payment_status(socket) do
        :success ->
          if socket.assigns[:cart_session_id],
            do: CartStore.clear_cart(socket.assigns.cart_session_id, socket.assigns.store.id)

          {:noreply,
           socket
           |> assign(:processing, false)
           |> redirect(
             to:
               store_path(socket.assigns.store.slug, "/orders/#{order.order_number}/confirmation")
           )}

        :failed ->
          {:noreply,
           socket
           |> assign(:processing, false)
           |> assign(:payment_status, :failed)
           |> put_flash(:error, "Payment failed. Please try again.")}

        :pending ->
          Process.send_after(self(), :poll_payment_status, @payment_poll_interval_ms)
          {:noreply, assign(socket, :poll_attempts, poll_attempts + 1)}
      end
    end
  end

  @impl true
  def handle_info(:tick_timer, socket) do
    if socket.assigns.timer_seconds > 0 and socket.assigns.payment_status == :awaiting_payment do
      Process.send_after(self(), :tick_timer, 1000)
      {:noreply, assign(socket, :timer_seconds, socket.assigns.timer_seconds - 1)}
    else
      {:noreply, socket}
    end
  end

  # Webhook-driven payment success — typically fires within 1-2s of the
  # customer confirming on the gateway, which is faster than the next 3s
  # poll. We complete the flow and redirect to the confirmation page.
  @impl true
  def handle_info({:payment_succeeded, _reference, _payment}, socket) do
    order = socket.assigns.order

    if order && socket.assigns.payment_status == :awaiting_payment do
      if socket.assigns[:cart_session_id],
        do: CartStore.clear_cart(socket.assigns.cart_session_id, socket.assigns.store.id)

      {:noreply,
       socket
       |> assign(:processing, false)
       |> redirect(
         to: store_path(socket.assigns.store.slug, "/orders/#{order.order_number}/confirmation")
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:payment_failed, _reference, _payment}, socket) do
    if socket.assigns.payment_status == :awaiting_payment do
      {:noreply,
       socket
       |> assign(:processing, false)
       |> assign(:payment_status, :failed)
       |> put_flash(:error, "Payment failed. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:payment_refunded, _reference, _payment}, socket),
    do: {:noreply, socket}

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:order_total, calculate_order_total(assigns))
      |> assign(:effective_delivery_fee, effective_delivery_fee(assigns))

    theme_content =
      case Emakola.Themes.ThemeRenderer.theme_render(assigns, :checkout) do
        {:ok, rendered} -> rendered
        :default -> Emakola.Themes.DefaultRenderers.Checkout.render(assigns)
      end

    assigns = assign(assigns, :theme_content, theme_content)

    ~H"""
    <aside
      :if={@sales_team_economics}
      id="sales-team-economics"
      class="border-b border-indigo-200 bg-indigo-50 px-4 py-3 text-center text-xs text-indigo-950"
    >
      <p class="font-bold">This order supports {@sales_team_economics.name}</p>
      <p id="sales-team-splits" class="mt-1">
        <span :for={member <- @sales_team_economics.members} class="mr-2 capitalize">
          {member.role}: {member.percent}%
        </span>
      </p>
      <p class="mt-1 text-indigo-700">
        Their split comes from merchant proceeds and does not increase your price.
      </p>
    </aside>
    {@theme_content}
    """
  end

  # render_default/1 (was here, ~880 lines) was extracted to
  # Emakola.Themes.DefaultRenderers.Checkout.render/1 along with
  # momo_waiting_state/1 and the display helpers (delivery_estimate,
  # momo_brand_color, momo_brand_name, format_timer, mask_phone).
  # CheckoutLive now keeps only events, data loading, and gateway code.
  # -- Private Helpers ------------------------------------------------------

  defp create_order(socket) do
    %{
      store: store,
      cart: cart,
      phone: phone,
      fullname: fullname,
      address: address,
      region: region,
      notes: notes,
      digital_address: digital_address,
      landmark: landmark
    } = socket.assigns

    items = Enum.map(cart, fn item -> %{variant_id: item.variant_id, quantity: item.quantity} end)

    shipping_address =
      %{
        "name" => fullname,
        "phone" => "+233#{phone}",
        "address" => address,
        "region" => region
      }
      |> put_digital_address(digital_address)
      |> put_landmark(landmark)

    delivery_fee = socket.assigns[:delivery_fee] || 0

    opts = [
      notes: notes,
      shipping_address: shipping_address,
      delivery_fee: delivery_fee,
      region: socket.assigns.region,
      attribution: socket.assigns[:utm_attribution] || %{}
    ]

    opts =
      if socket.assigns.coupon do
        Keyword.put(opts, :coupon_id, socket.assigns.coupon.id)
      else
        opts
      end

    CheckoutService.checkout!(store.id, items, opts)
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

  defp handle_payment(socket, order) do
    case socket.assigns.payment_method do
      "cod" ->
        if socket.assigns[:cart_session_id],
          do: CartStore.clear_cart(socket.assigns.cart_session_id, socket.assigns.store.id)

        {:noreply,
         socket
         |> assign(:processing, false)
         |> redirect(
           to: store_path(socket.assigns.store.slug, "/orders/#{order.order_number}/confirmation")
         )}

      method when method in ["momo", "vodafone", "card"] ->
        initiate_gateway_payment(socket, order, method)

      _ ->
        {:noreply,
         socket |> assign(:processing, false) |> put_flash(:error, "Unknown payment method")}
    end
  end

  defp initiate_gateway_payment(socket, order, method) do
    store = socket.assigns.store
    gateway = Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

    # Resolve how the charge is split at the gateway: a trustless dropship split
    # across wholesaler(s) + dropshipper, or — for a normal own-stock order with
    # a verified subaccount — the merchant's net with the platform keeping its
    # fee. Falls back to settling via the main account when neither applies.
    settlement = Emakola.Payments.OrderSettlement.prepare(order.id, store.id)

    params =
      %{
        amount: order.total,
        email: paystack_email(socket.assigns, store),
        currency: store.currency || "GHS",
        order_id: order.id,
        store_id: store.id,
        order_reference: order.order_number,
        callback_url:
          "#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/orders/#{order.order_number}/confirmation",
        return_url:
          "#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/orders/#{order.order_number}/confirmation",
        channel: paystack_channel(method),
        metadata: %{payment_method: method}
      }
      |> maybe_attach_split(settlement)

    case gateway.initiate_payment(params) do
      {:ok, %{reference: reference} = resp} ->
        case Emakola.Payments.create_payment(
               Map.merge(
                 %{
                   store_id: store.id,
                   order_id: order.id,
                   amount: order.total,
                   currency: store.currency || "GHS",
                   gateway: :paystack,
                   gateway_reference: reference,
                   metadata: %{payment_method: method},
                   split_mode: split_mode(settlement)
                 },
                 payout_hold_attrs(settlement)
               ),
               authorize?: false
             ) do
          {:ok, payment} ->
            record_splits(payment, settlement)
            :ok

          {:error, reason} ->
            require Logger

            Logger.error(
              "[Checkout] Failed to create payment record for order #{order.order_number}: #{inspect(reason)}"
            )
        end

        if method == "card" do
          url = Map.get(resp, :authorization_url, "")

          if url != "",
            do: {:noreply, socket |> assign(:processing, false) |> redirect(external: url)},
            else:
              {:noreply,
               socket
               |> assign(:processing, false)
               |> redirect(
                 to: store_path(store.slug, "/orders/#{order.order_number}/confirmation")
               )}
        else
          # Guard against disconnected static render — without this, the
          # timer/poll messages leak into a process that has no client to
          # render to and never get handled.
          if connected?(socket) do
            # Subscribe to webhook-driven payment updates so we react
            # immediately when Paystack confirms (instead of waiting up
            # to 3s for the next poll). Polling stays as a fallback in
            # case the webhook is delayed or the LV process restarted.
            Phoenix.PubSub.subscribe(Emakola.PubSub, "payment:#{reference}")

            Process.send_after(self(), :poll_payment_status, @payment_poll_interval_ms)
            Process.send_after(self(), :tick_timer, 1000)
          end

          {:noreply,
           socket
           |> assign(:payment_status, :awaiting_payment)
           |> assign(:gateway_reference, reference)
           |> assign(:timer_seconds, 180)}
        end

      {:error, reason} ->
        release_recovery_reservations(settlement)

        # The raw reason carries gateway internals (status codes, API keys
        # hints, provider payloads) — log it for operators, never render it
        # to the shopper.
        Logger.error(
          "[Checkout] Payment initiation failed for order #{order.order_number}: #{inspect(reason)}"
        )

        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:checkout_error, "Payment initiation failed.")
         |> put_flash(
           :error,
           "We couldn't start your payment just now. Your order #{order.order_number} is saved — please try again."
         )}
    end
  end

  # -- Settlement split helpers --------------------------------------------

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

  defp record_splits(payment, {:split, %{allocations: allocations}}),
    do: Emakola.Payments.OrderSettlement.record_splits!(payment, allocations)

  defp record_splits(_payment, {:no_split, _}), do: :ok
  defp record_splits(_payment, {:hold, _}), do: :ok

  defp release_recovery_reservations({:split, %{allocations: allocations}}),
    do: Emakola.Payments.OrderSettlement.release_recovery_reservations!(allocations)

  defp release_recovery_reservations({:no_split, _}), do: :ok
  defp release_recovery_reservations({:hold, _}), do: :ok

  defp verify_payment_status(socket) do
    ref = socket.assigns[:gateway_reference]

    if ref do
      gateway =
        Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

      case gateway.verify_payment(ref) do
        {:ok, %{status: status}} when status in [:success, "success", "Paid", "Success"] ->
          :success

        {:ok, %{status: status}} when status in [:failed, "failed", "Failed", "Expired"] ->
          :failed

        _ ->
          :pending
      end
    else
      :pending
    end
  end

  defp paystack_channel("momo"), do: "mobile_money"
  defp paystack_channel("vodafone"), do: "mobile_money"
  defp paystack_channel("card"), do: "card"
  defp paystack_channel(_), do: "mobile_money"

  # Resolves the email Paystack receives for this transaction.
  #
  # Preference order:
  #   1. customer-provided email (real address — best for receipts)
  #   2. store contact email (so transactions land under the merchant)
  #   3. a deterministic, store-scoped placeholder
  #
  # Crucially, we never synthesise per-customer fake addresses anymore — the
  # earlier `#{phone}@checkout.emakola.com` pattern polluted Paystack's
  # customer database with thousands of unrouteable addresses.
  defp paystack_email(assigns, store) do
    cond do
      assigns[:email] not in [nil, ""] -> assigns.email
      Map.get(store, :contact_email) not in [nil, ""] -> store.contact_email
      true -> "checkout+#{store.slug}@emakola.com"
    end
  end

  # Default per-region fees used when the merchant has not configured a
  # `Emakola.Shipping.DeliveryZone`. Kept as a fallback so onboarding stores
  # can take orders before configuring zones; merchants who configure zones
  # override this entirely.
  @default_region_fees %{
    "greater_accra" => 1500,
    "ashanti" => 2500,
    "central" => 2500
  }
  @default_region_fee 3500

  defp update_delivery_fee(socket) do
    region = socket.assigns.region
    store_id = socket.assigns.store.id

    {fee, estimate} =
      case Emakola.Shipping.find_zone(store_id, region) do
        {:ok, zone} ->
          {zone_fee(socket, zone), delivery_estimate(zone)}

        {:error, :no_zone} ->
          {Map.get(@default_region_fees, region, @default_region_fee), nil}
      end

    socket
    |> assign(:delivery_fee, fee)
    |> assign(:delivery_estimate, estimate)
  end

  # Live preview of the per-supplier dispatch fees CheckoutService.checkout!
  # will snapshot on the order. The LV's cart items are CartStore entries
  # (product_title/unit_price/sku display fields), not the
  # `%{variant_id, quantity}` + variants-map shape dispatch_fees_for/3
  # expects, so we adapt: build items from the cart against the
  # `:dispatch_variants` map cached at mount (mirroring cart_weight_grams's
  # pattern), keeping this a pure recompute with no DB hit on every
  # keystroke of the contact form. Items whose variant no longer exists
  # (the map is stale, or was never populated for it) are dropped before
  # calling dispatch_fees_for/3, which otherwise assumes every item has a
  # matching variant.
  defp update_dispatch_fees(socket) do
    variants = socket.assigns.dispatch_variants

    items =
      socket.assigns.cart
      |> Enum.filter(&Map.has_key?(variants, &1.variant_id))
      |> Enum.map(fn item -> %{variant_id: item.variant_id, quantity: item.quantity} end)

    dispatch_fee_total =
      items
      |> CheckoutService.dispatch_fees_for(variants, socket.assigns.region)
      |> Map.values()
      |> Enum.sum()

    assign(socket, :dispatch_fee_total, dispatch_fee_total)
  end

  defp dispatch_variants([], _store_id), do: %{}

  defp dispatch_variants(cart, store_id) do
    variant_ids = Enum.map(cart, & &1.variant_id)

    Emakola.Catalog.Variant
    |> Ash.Query.filter(id in ^variant_ids and store_id == ^store_id)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1})
  end

  defp zone_fee(socket, zone) do
    case Emakola.Shipping.calculate_fee(socket.assigns.store.id, zone.name,
           subtotal_pesewas: socket.assigns.cart_total,
           total_weight_grams: socket.assigns.cart_weight_grams
         ) do
      {:ok, fee} -> fee
      {:error, :no_zone} -> zone.fee
    end
  end

  # The checkout used to print a delivery estimate keyed off the region alone —
  # "1-2 business days" for Greater Accra, "3-5" for everywhere else — while
  # charging a fee taken from the merchant's own delivery zone. The price was
  # the merchant's; the promise beside it was ours, and no merchant could change
  # it. Both now come from the same row. A store that has configured no zone for
  # this region has promised no timeline, so the checkout states none.
  defp delivery_estimate(%{estimated_days: days}) when is_integer(days) do
    case days do
      0 -> "Same day"
      1 -> "Next day"
      n -> "About #{n} days"
    end
  end

  defp delivery_estimate(_zone), do: nil

  # Total cart weight in grams for weight-based delivery pricing. Variants
  # without a configured weight count as 0.
  defp cart_weight_grams([], _store_id), do: 0

  defp cart_weight_grams(cart, store_id) do
    variant_ids = Enum.map(cart, & &1.variant_id)

    weights =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(id in ^variant_ids and store_id == ^store_id)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1.weight_grams})

    cart
    |> Enum.map(&%{weight_grams: Map.get(weights, &1.variant_id), quantity: &1.quantity})
    |> Emakola.Shipping.total_weight_grams()
  end

  defp validate_contact_fields(assigns) do
    errors = %{}

    errors =
      if assigns.phone == "",
        do: Map.put(errors, :phone, "Phone number is required"),
        else: errors

    errors =
      if assigns.fullname == "",
        do: Map.put(errors, :fullname, "Full name is required"),
        else: errors

    errors =
      if assigns.address == "",
        do: Map.put(errors, :address, "Delivery address is required"),
        else: errors

    errors =
      if Emakola.GhanaDigitalAddress.valid?(assigns[:digital_address]) do
        errors
      else
        Map.put(
          errors,
          :digital_address,
          "Check the digital address — it looks like GA-183-8164"
        )
      end

    # Email is optional, but if provided must look like an email address.
    email = assigns[:email] || ""

    if email != "" and not email_format_ok?(email) do
      Map.put(errors, :email, "Email format looks invalid")
    else
      errors
    end
  end

  defp email_format_ok?(email) do
    String.contains?(email, "@") and
      String.split(email, "@") |> length() == 2 and
      String.length(email) <= 320
  end

  defp calculate_order_total(assigns) do
    max(
      assigns.cart_total - assigns.discount_amount + effective_delivery_fee(assigns) +
        assigns.dispatch_fee_total,
      0
    )
  end

  defp effective_delivery_fee(assigns) do
    if assigns.coupon && Map.get(assigns.coupon, :type) == :free_shipping do
      0
    else
      assigns.delivery_fee
    end
  end

  defp checkout_error_message(:empty_cart), do: "Your cart is empty"
  defp checkout_error_message(:variant_not_found), do: "Some items are no longer available"
  defp checkout_error_message(:variant_not_in_store), do: "Some items are not from this store"
  defp checkout_error_message(:insufficient_stock), do: "Some items are out of stock"

  defp checkout_error_message(:reseller_payout_unverified),
    do: "This store is finishing payout verification. Please try again soon."

  defp checkout_error_message(:wholesaler_payout_unverified),
    do: "A fulfillment partner is finishing payout verification. Please try again soon."

  defp checkout_error_message(:network_coupon_not_allowed),
    do: "Coupons cannot be used with partner-fulfilled products yet."

  defp checkout_error_message(_), do: "Something went wrong. Please try again."

  defp coupon_error_message(:coupon_not_found), do: "Coupon code not found"
  defp coupon_error_message(:coupon_inactive), do: "This coupon is no longer active"
  defp coupon_error_message(:coupon_expired), do: "This coupon has expired"
  defp coupon_error_message(:coupon_not_started), do: "This coupon is not yet active"
  defp coupon_error_message(:coupon_minimum_not_met), do: "Order does not meet the minimum amount"

  defp coupon_error_message(:network_coupon_not_allowed),
    do: "Coupons cannot be used with partner-fulfilled products yet"

  defp coupon_error_message(:coupon_max_uses_reached),
    do: "This coupon has reached its usage limit"
end
