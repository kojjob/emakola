defmodule EmakolaWeb.Storefront.SusuLinkLive do
  @moduledoc """
  Buyer-facing susu (lay-away) plan page (`/susu/:code`, apex host) — BOTH
  faces in one LiveView, mirroring `PayLinkLive`'s structural template
  (apex live_session, storefront layout, Mox gateway initiation + friendly
  error mapping, search_overlay handlers).

  ## Public vs signed face

  The bare code is intentionally public — anyone with it can view a
  `:pending` plan's summary and submit the FIRST chunk (`usable_for_start?/1`
  authority: view + start only, no token). A token only exists after
  activation (delivered to the buyer at that point — Task 8's
  notification), so a still-`:pending` plan shows the same start form
  regardless of any `t` param.

  Once `:active`, the public face is read-only (progress + a "resend my
  link" phone lookup — no chunk/cancel/edit). The SIGNED face (`?t=`
  verifies via `EmakolaWeb.SusuTokens` AND the verified plan id matches
  THIS plan) is where chunk/edit/cancel live. `authorized?` is computed
  once at mount and re-checked at the top of every money-moving
  `handle_event` — a direct event push on an unauthorized socket (bypassing
  the rendered UI) must never move money or cancel/edit (TC-3 threat
  suite).

  ## States

  `page_state/4` folds store lifecycle, catalog stock, plan status, and
  `authorized?` into one atom the render clauses switch on:

    * `:store_unavailable` — suspended/blocked store (both faces; chunk
      initiation pauses, existing contributions untouched — expiry handles
      the rest, same posture as `PayLinkLive`).
    * `:sold_out` — pending catalog plan whose variant can no longer cover
      `plan.quantity` (upfront, friendlier block — activation's
      cancel-and-flag in `SusuChunks` remains the backstop for the harder
      race).
    * `:pending` — start form (either face; see above).
    * `:active_public` — progress + resend-my-link.
    * `:active_signed` — progress + next-chunk form + delivery edit (while
      `collect_delivery`) + cancel button.
    * `:completed_signed` — link to the order's tracking page.
    * `:closed` — completed-but-unsigned, expired, or cancelled (any
      face) — a single friendly message, no forms.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Accounts.PhoneAuth
  alias Emakola.Orders.SusuChunks
  alias Emakola.Orders.SusuLifecycle
  alias Emakola.Orders.SusuPlan
  alias EmakolaWeb.Helpers.Currency
  alias EmakolaWeb.SusuTokens
  alias EmakolaWeb.TrackingTokens

  @impl true
  def mount(%{"code" => code} = params, _session, socket) do
    case Emakola.Orders.get_susu_plan_by_code(code, authorize?: false) do
      {:ok, plan} ->
        store = Ash.get!(Emakola.Stores.Store, plan.store_id, authorize?: false)
        variant = load_variant(plan)
        authorized? = authorized?(params["t"], plan.id)
        state = page_state(plan, store, variant, authorized?)

        {:ok,
         socket
         |> assign(:plan, plan)
         |> assign(:store, store)
         |> assign(:variant, variant)
         |> assign(:authorized?, authorized?)
         |> assign(:state, state)
         |> assign(:tracking_url, maybe_tracking_url(state, plan, store))
         |> assign(:amount, "")
         |> assign(:processing, false)
         |> assign(:buyer, %{"name" => "", "phone" => "", "email" => "", "address" => ""})
         |> assign(:delivery, delivery_fields(plan))
         |> assign(:form_errors, %{})
         |> assign(:page_title, store.name)
         # The storefront layout renders the search overlay whenever @store is
         # assigned (true in every state this LiveView renders) — see
         # `PayLinkLive`'s identical comment.
         |> assign(:search_overlay_query, "")
         |> assign(:search_overlay_results, [])
         |> assign(:search_overlay_total, 0)
         |> assign(:searching, false)}

      {:error, _} ->
        raise Ash.Error.Query.NotFound
    end
  end

  # -- Event handlers ---------------------------------------------------
  #
  # All `handle_event/3` clauses live together in this one block (Elixir
  # requires same-name/arity clauses to be textually grouped) — private
  # helpers follow further down.

  @impl true
  def handle_event("validate", params, socket) do
    socket =
      socket
      |> maybe_assign_scalar(:amount, params["amount"])
      |> maybe_assign_nested(:buyer, params["buyer"])
      |> maybe_assign_nested(:delivery, params["delivery"])

    {:noreply, socket}
  end

  # The storefront layout mounts `EmakolaWeb.SearchComponents.search_overlay`
  # unconditionally whenever `@store` is assigned — true in every state this
  # LiveView renders. Mirrors `PayLinkLive`'s identical handlers.
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

  # Public entry point — no `authorized?` gate BY DESIGN (a still-pending
  # plan has no signed token to check yet). The critical guard is `state ==
  # :pending`: without it, a direct "start" event push on an ALREADY-active
  # plan's page would let anyone move money without ever holding the signed
  # link (the whole point of the signed face). SusuChunks itself would
  # still accept it as a valid subsequent chunk (`initiate_chunk/4` allows
  # both :pending and :active), so this state check is the only thing
  # standing between "start" and "chunk"'s authorization requirement.
  @impl true
  def handle_event("start", %{"amount" => amount_str, "buyer" => buyer}, socket) do
    if socket.assigns.state == :pending do
      handle_pending_submit(socket, amount_str, buyer)
    else
      {:noreply, socket}
    end
  end

  # Signed face only — a direct "chunk" push on an unauthorized socket must
  # never reach `SusuChunks.initiate_chunk/4` (TC-3 threat suite).
  @impl true
  def handle_event("chunk", %{"amount" => amount_str}, socket) do
    if socket.assigns.authorized? do
      socket |> assign(:amount, amount_str) |> submit_chunk(amount_str, %{})
    else
      {:noreply, socket}
    end
  end

  # Signed face only. Re-fetches the plan fresh (not the possibly-stale
  # mount-time struct) before checking it's still cancellable — a direct
  # push on an unauthorized socket must never cancel (and thus never
  # trigger a refund).
  @impl true
  def handle_event("cancel_plan", _params, socket) do
    if socket.assigns.authorized? do
      fresh = reload_plan(socket.assigns.plan.id)

      if fresh.status in [:pending, :active] do
        {:ok, cancelled} = SusuLifecycle.cancel(fresh, :buyer)
        {:noreply, refresh_from_plan(socket, cancelled)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Signed face, active plans only — mirrors `SusuPlan.:update_delivery`'s
  # own status guard. A direct push on an unauthorized socket must never
  # change delivery details.
  @impl true
  def handle_event("update_delivery", %{"delivery" => delivery_params}, socket) do
    if socket.assigns.authorized? do
      fresh = reload_plan(socket.assigns.plan.id)

      if fresh.status == :active do
        case Emakola.Orders.update_susu_plan_delivery(
               fresh,
               %{delivery_address: delivery_params},
               authorize?: false
             ) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> refresh_from_plan(updated)
             |> assign(:delivery, delivery_fields(updated))
             |> put_flash(:info, "Delivery details updated.")}

          {:error, _reason} ->
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Active public face. Always claims success regardless of match — never
  # reveals whether the entered number is the one on file (TC-3 spec: "no
  # enumeration").
  @impl true
  def handle_event("resend_link", %{"phone" => phone}, socket) do
    maybe_resend(socket.assigns.plan, phone)

    {:noreply,
     put_flash(socket, :info, "If that number is on file, we've texted your susu link.")}
  end

  # -- Authority ------------------------------------------------------------

  # A token verifies AND must match THIS plan's id — a genuinely signed
  # token minted for a different plan is unauthorized here (TC-3 threat:
  # "wrong-plan valid token unauthorized").
  defp authorized?(token, plan_id) when is_binary(token) do
    case SusuTokens.verify_susu_plan(token) do
      {:ok, ^plan_id} -> true
      _ -> false
    end
  end

  defp authorized?(_token, _plan_id), do: false

  # -- Page state -------------------------------------------------------

  defp page_state(plan, store, variant, authorized?) do
    cond do
      not Emakola.Stores.Store.live?(store) ->
        :store_unavailable

      plan.status == :pending and plan.type == :catalog and out_of_stock?(plan, variant) ->
        :sold_out

      plan.status == :pending ->
        :pending

      plan.status == :active and authorized? ->
        :active_signed

      plan.status == :active ->
        :active_public

      plan.status == :completed and authorized? ->
        :completed_signed

      true ->
        :closed
    end
  end

  defp load_variant(%SusuPlan{type: :catalog, variant_id: variant_id})
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

  defp load_variant(%SusuPlan{}), do: nil

  defp out_of_stock?(_plan, nil), do: true

  defp out_of_stock?(plan, variant),
    do: not Emakola.Catalog.Variant.in_stock?(variant, plan.quantity)

  defp delivery_fields(%SusuPlan{delivery_address: %{} = addr}) do
    %{
      "name" => addr["name"] || "",
      "phone" => addr["phone"] || "",
      "address" => addr["address"] || ""
    }
  end

  defp delivery_fields(_plan), do: %{"name" => "", "phone" => "", "address" => ""}

  defp maybe_tracking_url(:completed_signed, plan, store), do: tracking_url(plan, store)
  defp maybe_tracking_url(_state, _plan, _store), do: nil

  # The order a completed plan's final chunk created — `SusuCompletion`
  # stamps `susu_plan_id` on it (see its moduledoc). Signed to the same
  # buyer-authorization token `TrackingLive` already checks, so a completed
  # susu plan flows straight into the ordinary tracking page.
  defp tracking_url(plan, store) do
    Emakola.Orders.Order
    |> Ash.Query.filter(susu_plan_id == ^plan.id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
    |> case do
      nil ->
        nil

      order ->
        token = TrackingTokens.sign_order_tracking(order.id)
        "/s/#{store.slug}/track/#{order.order_number}?t=#{token}"
    end
  end

  defp reload_plan(plan_id), do: Ash.get!(SusuPlan, plan_id, authorize?: false)

  defp refresh_from_plan(socket, plan) do
    variant = load_variant(plan)
    state = page_state(plan, socket.assigns.store, variant, socket.assigns.authorized?)

    socket
    |> assign(:plan, plan)
    |> assign(:variant, variant)
    |> assign(:state, state)
    |> assign(:tracking_url, maybe_tracking_url(state, plan, socket.assigns.store))
  end

  defp progress_percent(%SusuPlan{total_amount: total}) when total <= 0, do: 0

  defp progress_percent(%SusuPlan{total_amount: total, contributed_amount: contributed}) do
    (contributed / total * 100) |> Float.round(0) |> trunc() |> min(100)
  end

  defp closed_message(:completed), do: "This susu plan has been fully paid — thank you!"
  defp closed_message(:expired), do: "This susu plan has expired."

  defp closed_message(:cancelled),
    do: "This susu plan was cancelled and any payments were refunded."

  defp closed_message(_status), do: "This susu plan is no longer active."

  # -- "validate" helpers (keeps controlled inputs in sync while typing) --

  defp maybe_assign_scalar(socket, _key, nil), do: socket
  defp maybe_assign_scalar(socket, key, value), do: assign(socket, key, value)

  defp maybe_assign_nested(socket, _key, nil), do: socket

  defp maybe_assign_nested(socket, key, params),
    do: assign(socket, key, Map.merge(Map.fetch!(socket.assigns, key), params))

  # -- Search overlay helpers (copied from PayLinkLive) --------------------

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

  # -- Chunk submission (shared by "start" and "chunk") --------------------

  defp handle_pending_submit(socket, amount_str, buyer) do
    %{plan: plan} = socket.assigns
    fresh_variant = if plan.type == :catalog, do: load_variant(plan), else: nil

    socket =
      socket
      |> assign(:amount, amount_str)
      |> assign(:buyer, Map.merge(socket.assigns.buyer, buyer))

    if plan.type == :catalog and out_of_stock?(plan, fresh_variant) do
      {:noreply, socket |> assign(:variant, fresh_variant) |> assign(:state, :sold_out)}
    else
      submit_chunk(socket, amount_str, buyer)
    end
  end

  defp submit_chunk(socket, amount_str, buyer_params) do
    case parse_ghs_amount(amount_str) do
      {:ok, amount} ->
        gateway =
          Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

        case SusuChunks.initiate_chunk(socket.assigns.plan, amount, buyer_params, gateway) do
          {:ok, %{gateway: resp}} ->
            case Map.get(resp, :authorization_url, "") do
              "" ->
                {:noreply,
                 socket
                 |> assign(:processing, false)
                 |> put_flash(:info, "Payment started — check your phone to complete it.")}

              url ->
                {:noreply, socket |> assign(:processing, false) |> redirect(external: url)}
            end

          {:error, reason} ->
            {:noreply,
             assign(socket, form_errors: %{base: friendly_error(reason)}, processing: false)}
        end

      {:error, message} ->
        {:noreply, assign(socket, form_errors: %{base: message}, processing: false)}
    end
  end

  # Better than `trunc(Decimal.to_float(...) * 100)` — stays in Decimal
  # arithmetic throughout (mirrors `Admin.PayLinkLive.Index.parse_ghs/1`).
  defp parse_ghs_amount(value) do
    pesewas =
      value
      |> to_string()
      |> String.trim()
      |> Decimal.new()
      |> Decimal.mult(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()

    {:ok, pesewas}
  rescue
    _ -> {:error, "Enter a valid amount in GH₵, e.g. 50 or 50.00."}
  end

  defp friendly_error(:completed), do: "This susu plan is already fully paid."
  defp friendly_error(:cancelled), do: "This susu plan is no longer active."
  defp friendly_error(:expired), do: "This susu plan has expired."

  defp friendly_error(:chunk_in_flight),
    do: "A payment for this plan is already being processed — please wait and try again."

  defp friendly_error(:amount_below_min), do: "Enter at least the minimum chunk amount."

  defp friendly_error(:amount_above_remaining),
    do: "That's more than what's left to pay — enter a smaller amount."

  defp friendly_error(:buyer_details_required), do: "Please enter your name and phone number."
  defp friendly_error(:plan_not_found), do: "This susu plan could not be found."
  defp friendly_error(_reason), do: "We couldn't process that — please try again."

  # -- Resend link -----------------------------------------------------

  defp maybe_resend(%SusuPlan{customer_id: nil}, _phone), do: :ok

  defp maybe_resend(%SusuPlan{customer_id: customer_id} = plan, phone) when is_binary(phone) do
    with {:ok, customer} <- Ash.get(Emakola.Customers.Customer, customer_id, authorize?: false),
         true <- phones_match?(customer.phone, phone) do
      send_resend_sms(plan, customer.phone)
    else
      _ -> :ok
    end
  end

  defp maybe_resend(_plan, _phone), do: :ok

  defp phones_match?(on_file, entered) do
    case {presence(on_file), presence(entered)} do
      {nil, _} -> false
      {_, nil} -> false
      {a, b} -> PhoneAuth.normalize(a) == PhoneAuth.normalize(b)
    end
  end

  defp send_resend_sms(plan, phone) do
    token = SusuTokens.sign_susu_plan(plan.id)
    url = "#{EmakolaWeb.Endpoint.url()}/susu/#{plan.code}?t=#{token}"
    sms_provider().send_sms(phone, "Continue your susu plan: #{url}", store_id: plan.store_id)
  end

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)

  defp presence(nil), do: nil

  defp presence(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp presence(_value), do: nil

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

  def render(%{state: :sold_out} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">This item just sold out — contact the seller.</p>
    </div>
    """
  end

  def render(%{state: :closed} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">{closed_message(@plan.status)}</p>
    </div>
    """
  end

  def render(%{state: :completed_signed} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-16 text-center">
      <h1 class="text-lg font-semibold text-slate-900">{@store.name}</h1>
      <p class="mt-3 text-sm text-[#94A3B8]">Your susu plan is fully paid!</p>
      <a
        :if={@tracking_url}
        href={@tracking_url}
        class="mt-6 inline-block rounded-lg bg-store-accent px-4 py-3 text-sm font-semibold text-white"
      >
        Track your order
      </a>
    </div>
    """
  end

  def render(%{state: :pending} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-8 sm:py-12">
      <p class="text-sm font-medium text-[#94A3B8]">Susu plan · {@store.name}</p>
      <.item_summary plan={@plan} variant={@variant} store={@store} />
      <.progress_block plan={@plan} store={@store} />

      <p :if={@form_errors[:base]} class="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
        {@form_errors.base}
      </p>

      <form id="susu-start-form" phx-submit="start" phx-change="validate" class="mt-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-slate-700" for="susu-amount">
            Amount to pay now
          </label>
          <p class="mt-1 text-xs text-[#94A3B8]">
            Between {Currency.format_price(SusuPlan.chunk_bounds(@plan).min, @store.currency || "GHS")} and {Currency.format_price(
              SusuPlan.chunk_bounds(@plan).max,
              @store.currency || "GHS"
            )}
          </p>
          <input
            type="text"
            id="susu-amount"
            name="amount"
            value={@amount}
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="susu-name">Full name</label>
          <input
            type="text"
            id="susu-name"
            name="buyer[name]"
            value={@buyer["name"]}
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="susu-phone">
            Phone number
          </label>
          <input
            type="tel"
            id="susu-phone"
            name="buyer[phone]"
            value={@buyer["phone"]}
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700" for="susu-email">
            Email (optional)
          </label>
          <input
            type="email"
            id="susu-email"
            name="buyer[email]"
            value={@buyer["email"]}
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <div :if={@plan.collect_delivery}>
          <label class="block text-sm font-medium text-slate-700" for="susu-address">
            Delivery address
          </label>
          <textarea
            id="susu-address"
            name="buyer[address]"
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          >{@buyer["address"]}</textarea>
        </div>

        <button
          type="submit"
          phx-disable-with="Processing..."
          disabled={@processing}
          class="w-full rounded-lg bg-store-accent px-4 py-3 text-sm font-semibold text-white disabled:opacity-60"
        >
          Pay now
        </button>
      </form>
    </div>
    """
  end

  def render(%{state: :active_public} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-8 sm:py-12">
      <p class="text-sm font-medium text-[#94A3B8]">Susu plan · {@store.name}</p>
      <.item_summary plan={@plan} variant={@variant} store={@store} />
      <.progress_block plan={@plan} store={@store} />

      <div class="mt-8 rounded-2xl border border-[#E2E8F0] bg-white p-4">
        <h2 class="text-sm font-semibold text-slate-900">Lost your link?</h2>
        <p class="mt-1 text-xs text-[#94A3B8]">
          Enter the phone number on file and we'll text it to you.
        </p>
        <form id="susu-resend-form" phx-submit="resend_link" class="mt-3 flex gap-2">
          <input
            type="tel"
            name="phone"
            required
            placeholder="Phone number"
            class="flex-1 rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
          <button
            type="submit"
            class="rounded-lg bg-store-accent px-4 py-2 text-sm font-semibold text-white"
          >
            Resend
          </button>
        </form>
      </div>
    </div>
    """
  end

  def render(%{state: :active_signed} = assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-8 sm:py-12">
      <p class="text-sm font-medium text-[#94A3B8]">Your susu plan · {@store.name}</p>
      <.item_summary plan={@plan} variant={@variant} store={@store} />
      <.progress_block plan={@plan} store={@store} />

      <p :if={@form_errors[:base]} class="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
        {@form_errors.base}
      </p>

      <form id="susu-chunk-form" phx-submit="chunk" phx-change="validate" class="mt-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-slate-700" for="susu-amount">
            Pay another chunk
          </label>
          <p class="mt-1 text-xs text-[#94A3B8]">
            Between {Currency.format_price(SusuPlan.chunk_bounds(@plan).min, @store.currency || "GHS")} and {Currency.format_price(
              SusuPlan.chunk_bounds(@plan).max,
              @store.currency || "GHS"
            )}
          </p>
          <input
            type="text"
            id="susu-amount"
            name="amount"
            value={@amount}
            required
            class="mt-1 w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
        </div>

        <button
          type="submit"
          phx-disable-with="Processing..."
          disabled={@processing}
          class="w-full rounded-lg bg-store-accent px-4 py-3 text-sm font-semibold text-white disabled:opacity-60"
        >
          Pay this chunk
        </button>
      </form>

      <div
        :if={@plan.collect_delivery}
        class="mt-8 rounded-2xl border border-[#E2E8F0] bg-white p-4"
      >
        <h2 class="text-sm font-semibold text-slate-900">Delivery details</h2>
        <form
          id="susu-delivery-form"
          phx-submit="update_delivery"
          phx-change="validate"
          class="mt-3 space-y-3"
        >
          <input
            type="text"
            name="delivery[name]"
            value={@delivery["name"]}
            placeholder="Full name"
            class="w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
          <input
            type="tel"
            name="delivery[phone]"
            value={@delivery["phone"]}
            placeholder="Phone number"
            class="w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          />
          <textarea
            name="delivery[address]"
            placeholder="Delivery address"
            class="w-full rounded-lg border border-[#E2E8F0] px-3 py-2 text-sm"
          >{@delivery["address"]}</textarea>
          <button
            type="submit"
            class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
          >
            Update delivery
          </button>
        </form>
      </div>

      <button
        type="button"
        phx-click="cancel_plan"
        data-confirm="Cancel this susu plan? Every payment you've made so far will be refunded in full."
        class="mt-8 w-full rounded-lg border border-red-200 px-4 py-3 text-sm font-semibold text-red-700"
      >
        Cancel this plan
      </button>
    </div>
    """
  end

  defp item_summary(assigns) do
    ~H"""
    <div class="mt-2 rounded-2xl border border-[#E2E8F0] bg-white p-4">
      <h1 class="text-base font-semibold text-slate-900">{item_title(@plan, @variant)}</h1>
      <p class="mt-1 text-lg font-bold text-slate-900">
        {Currency.format_price(@plan.total_amount, @store.currency || "GHS")}
      </p>
      <p class="mt-1 text-xs text-[#94A3B8]">
        Deadline: {Calendar.strftime(@plan.deadline, "%d %b %Y")}
      </p>
    </div>
    """
  end

  defp item_title(%SusuPlan{type: :catalog}, %{product: %{title: title}}), do: title
  defp item_title(%SusuPlan{type: :catalog}, _variant), do: "This item"
  defp item_title(%SusuPlan{type: :custom, title: title}, _variant), do: title

  defp progress_block(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="h-2 w-full rounded-full bg-slate-100">
        <div class="h-2 rounded-full bg-store-accent" style={"width: #{progress_percent(@plan)}%"}>
        </div>
      </div>
      <p class="mt-1 text-xs text-[#94A3B8]">
        {progress_percent(@plan)}% paid · {Currency.format_price(
          @plan.contributed_amount,
          @store.currency || "GHS"
        )} of {Currency.format_price(@plan.total_amount, @store.currency || "GHS")}
      </p>
    </div>
    """
  end
end
