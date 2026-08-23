defmodule EmakolaWeb.Platform.ProtectionLive do
  @moduledoc """
  Platform staff buyer-protection queue (TC-2 Task 12): frozen holds (an
  open buyer complaint) and stale holds (`:held`, never started the
  auto-release timer, 30+ days old) needing manual review.

  Gated by RequirePermission(:manage_billing) — the same permission as the
  rest of the money surfaces (Billing/Finance/Payments/Refunds). No DB
  queries in disconnected mount.

  Studio layout: a queue of frozen + stale holds on the left, the selected
  hold's case panel on the right. Two decisions per selected hold, both
  re-checking :manage_billing against a freshly
  reloaded user before acting and writing a `Emakola.Accounts.PlatformAudit`
  entry on success:

    * Force release — `ProtectionRelease.release(hold, :staff, respect_freeze:
      false)`. A frozen hold additionally gets `resolution:
      :released_by_staff`, stamped inside `ProtectionRelease` itself once it
      reads `frozen_at` off the FOR UPDATE-locked row.
    * Refund buyer — a full refund through the SAME `RefundService` the
      merchant returns flow uses, resolving a `Return` for the order first
      (see `resolve_return/1`: reuse a `:requested` one, `:reopen` a
      `:denied` one — the realistic path into this queue's Frozen list is a
      buyer escalating a return the merchant already denied — refuse with a
      distinguishable error if one is already `:approved`/`:refunded`, else
      create one) and passing `resolution: :refunded_by_staff, authorize?:
      false` (the platform staff actor has no Ash policy grant on
      `Return`/`Payment`). The hold does NOT close synchronously — only the
      refund webhook's terminal confirmation closes it (see
      `RefundService`'s "Buyer-protection hold" section) — so the flash
      says "initiated", not "refunded", and the row stays in the queue
      until the webhook lands.
  """
  use EmakolaWeb, :live_view
  require Ash.Query
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.ProtectionHold
  alias Emakola.Payments.ProtectionRelease
  alias Emakola.Payments.RefundService

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Buyer Protection")
      |> assign(:active_nav, :protection)
      |> assign(:holds_loaded?, false)
      |> assign(:frozen_holds_count, 0)
      |> assign(:stale_holds_count, 0)
      |> assign(:frozen_holds_total, money(0, "GHS"))
      |> assign(:stale_holds_total, money(0, "GHS"))
      |> assign(:oldest_hold_days, nil)
      |> assign(:hold_tenants, %{})
      |> assign(:holds_by_id, %{})
      |> assign(:selected_hold, nil)
      |> assign(:selected_section, nil)
      |> stream(:frozen_holds, [])
      |> stream(:stale_holds, [])

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("select_hold", %{"id" => id}, socket) do
    # Selection is read-only UI state; membership in the mounted queues is
    # the guard — a forged id simply no-ops.
    case Map.get(socket.assigns.holds_by_id, id) do
      nil ->
        {:noreply, socket}

      {section, hold} ->
        previously_selected = socket.assigns.selected_hold

        socket =
          socket
          |> assign(:selected_hold, hold)
          |> assign(:selected_section, section)
          |> refresh_queue_row(hold)

        socket =
          if previously_selected && previously_selected.id != hold.id do
            refresh_queue_row(socket, previously_selected)
          else
            socket
          end

        {:noreply, socket}
    end
  end

  def handle_event("force_release", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      case find_hold(socket, id) do
        nil ->
          {:noreply, socket}

        hold ->
          case ProtectionRelease.release(hold, :staff, respect_freeze: false) do
            :ok ->
              PlatformAudit.log(:protection_force_released, socket.assigns.current_user, %{
                "hold_id" => hold.id,
                "order_id" => hold.order_id,
                "store_id" => hold.store_id,
                "was_frozen" => not is_nil(hold.frozen_at)
              })

              {:noreply,
               socket
               |> load()
               |> put_flash(:info, "Hold released to the merchant.")}

            {:error, _reason} ->
              {:noreply, put_flash(socket, :error, "Could not release this hold.")}
          end
      end
    end)
  end

  def handle_event("refund_buyer", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      case find_hold(socket, id) do
        nil ->
          {:noreply, socket}

        hold ->
          case issue_refund(socket.assigns.current_user, hold) do
            {:ok, _return} ->
              PlatformAudit.log(:protection_refund_initiated, socket.assigns.current_user, %{
                "hold_id" => hold.id,
                "order_id" => hold.order_id,
                "store_id" => hold.store_id,
                "amount" => hold.amount
              })

              {:noreply,
               socket
               |> load()
               |> put_flash(
                 :info,
                 "Refund initiated — it will complete once the gateway confirms."
               )}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, refund_error(reason))}
          end
      end
    end)
  end

  defp issue_refund(actor, hold) do
    with {:ok, return} <- resolve_return(hold) do
      RefundService.issue(
        actor,
        return,
        %{
          refund_amount: hold.amount,
          refund_dispatch_fee?: false,
          admin_notes: "Buyer protection queue — staff refund"
        },
        nil,
        resolution: :refunded_by_staff,
        authorize?: false
      )
    end
  end

  # No prior customer return request is required to refund from the
  # protection queue — but plausibly one already exists, in EVERY terminal
  # state, since the realistic path into this queue's Frozen list is a
  # buyer escalating a return the merchant already acted on:
  #   :requested — reuse it as-is (the ordinary case).
  #   :denied    — the buyer's complaint is exactly staff overriding that
  #                denial, so :reopen it back to :requested first (Return's
  #                only transition out of :denied — TC-2 Task 12).
  #   :approved/:refunded — a refund is already moving or done; do NOT
  #                create a second Return (would collide with the
  #                unique_return_per_order identity) or silently reuse it —
  #                surface a distinguishable error instead so staff aren't
  #                stuck guessing at a generic failure.
  #   none       — create it (staff-initiated, mirrors how ModerationLive
  #                bypasses merchant-only actions with `authorize?: false`).
  defp resolve_return(hold) do
    case Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false) do
      {:ok, [%{status: :requested} = return | _]} ->
        {:ok, return}

      {:ok, [%{status: :denied} = return | _]} ->
        Emakola.Orders.reopen_return(return, authorize?: false)

      {:ok, [%{status: status} | _]} when status in [:approved, :refunded] ->
        {:error, :refund_already_in_progress}

      _ ->
        Emakola.Orders.request_return(
          %{
            store_id: hold.store_id,
            order_id: hold.order_id,
            customer_id: hold.order && hold.order.customer_id,
            reason: :other,
            reason_detail: "Buyer protection complaint"
          },
          authorize?: false
        )
    end
  end

  defp refund_error(:refund_already_in_progress),
    do: "A refund is already in progress or completed for this order."

  defp refund_error(:amount_exceeds_refundable),
    do: "This payment has a smaller refundable balance than the hold — check for a prior refund."

  defp refund_error(:gateway_unsupported),
    do: "This gateway has no refund API — issue it in the provider's dashboard."

  defp refund_error(:payment_not_found),
    do: "No payment was found for this order, so there is nothing to refund."

  defp refund_error(_reason), do: "Could not initiate the refund."

  defp find_hold(socket, id) do
    with {:ok, store_id} <- Map.fetch(socket.assigns.hold_tenants, id),
         {:ok, hold} <-
           ProtectionHold
           |> Ash.Query.filter(id == ^id and status == :held)
           |> Ash.Query.load([:store, :order])
           |> Ash.read_one(tenant: store_id, authorize?: false) do
      hold
    else
      _ -> nil
    end
  end

  # Re-check the permission against a fresh user (Iron Law: never trust mount).
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_billing) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage protection.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket) do
    frozen_holds = ProtectionHolds.list_frozen()
    stale_holds = ProtectionHolds.list_stale()

    hold_tenants =
      (frozen_holds ++ stale_holds)
      |> Map.new(&{&1.id, &1.store_id})

    holds_by_id =
      Map.new(
        Enum.map(frozen_holds, &{&1.id, {:frozen, &1}}) ++
          Enum.map(stale_holds, &{&1.id, {:stale, &1}})
      )

    # Keep the current selection when its hold is still queued (a refund
    # leaves the hold in place); otherwise fall back to the first hold.
    previously_selected_id = socket.assigns.selected_hold && socket.assigns.selected_hold.id

    {selected_section, selected_hold} =
      case Map.get(holds_by_id, previously_selected_id) do
        {section, hold} -> {section, hold}
        nil -> first_queued_hold(frozen_holds, stale_holds)
      end

    socket
    |> assign(:holds_loaded?, true)
    |> assign(:frozen_holds_count, length(frozen_holds))
    |> assign(:stale_holds_count, length(stale_holds))
    |> assign(:frozen_holds_total, total_held(frozen_holds))
    |> assign(:stale_holds_total, total_held(stale_holds))
    |> assign(:oldest_hold_days, oldest_days(frozen_holds ++ stale_holds))
    |> assign(:hold_tenants, hold_tenants)
    |> assign(:holds_by_id, holds_by_id)
    |> assign(:selected_hold, selected_hold)
    |> assign(:selected_section, selected_section)
    |> stream(:frozen_holds, frozen_holds, reset: true)
    |> stream(:stale_holds, stale_holds, reset: true)
  rescue
    exception ->
      Logger.error("[platform.protection_live] load raised: #{Exception.message(exception)}")

      socket
      |> assign(:holds_loaded?, true)
      |> assign(:frozen_holds_count, 0)
      |> assign(:stale_holds_count, 0)
      |> assign(:frozen_holds_total, money(0, "GHS"))
      |> assign(:stale_holds_total, money(0, "GHS"))
      |> assign(:oldest_hold_days, nil)
      |> assign(:hold_tenants, %{})
      |> assign(:holds_by_id, %{})
      |> assign(:selected_hold, nil)
      |> assign(:selected_section, nil)
      |> stream(:frozen_holds, [], reset: true)
      |> stream(:stale_holds, [], reset: true)
  end

  defp first_queued_hold([first_frozen | _], _stale_holds), do: {:frozen, first_frozen}
  defp first_queued_hold([], [first_stale | _]), do: {:stale, first_stale}
  defp first_queued_hold([], []), do: {nil, nil}

  # Re-render one already-streamed queue row so its data-selected state
  # follows the selection (stream rows don't re-render on assign changes).
  defp refresh_queue_row(socket, hold) do
    case Map.get(socket.assigns.holds_by_id, hold.id) do
      {:frozen, queued_hold} -> stream_insert(socket, :frozen_holds, queued_hold)
      {:stale, queued_hold} -> stream_insert(socket, :stale_holds, queued_hold)
      nil -> socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <div class="flex flex-wrap items-start justify-between gap-3 mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Buyer Protection</h1>
          <p class="text-sm text-gray-500 mt-1">
            Frozen holds (open complaints) and stale holds (30+ days, no auto-release timer) across all stores.
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.severity_pill label={"#{@frozen_holds_count} frozen"} tone="rose" />
          <.severity_pill label={"#{@stale_holds_count} stale"} tone="amber" />
        </div>
      </div>

      <%!-- What the queue is actually sitting on. Counts alone never said how
            much money was stuck. Same tiles as /platform, so the two pages
            read as one product. --%>
      <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
        <.stat_tile
          id="protection-frozen-total"
          label="Frozen by a complaint"
          value={@frozen_holds_total}
          icon="error"
          color="rose"
        />
        <.stat_tile
          id="protection-stale-total"
          label="Stale, no timer"
          value={@stale_holds_total}
          icon="hourglass_empty"
          color="amber"
        />
        <.stat_tile
          id="protection-oldest"
          label="Oldest waiting"
          value={oldest_label(@oldest_hold_days)}
          icon="flag"
          color="slate"
        />
      </div>

      <div class="flex flex-col lg:flex-row gap-5 items-start">
        <%!-- Queue --%>
        <div class="w-full lg:w-[360px] shrink-0 bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-4 pt-4 pb-1">
            <h2 class="text-[11px] font-bold uppercase tracking-wider text-rose-600">
              {"Frozen — open complaints · #{@frozen_holds_count}"}
            </h2>
          </div>
          <div id="frozen-protection-holds" phx-update="stream" class="px-2 pb-2">
            <div
              :if={!@holds_loaded?}
              id="frozen-protection-holds-loading"
              class="px-3 py-6 text-center text-sm text-gray-400"
            >
              Loading…
            </div>
            <div
              :if={@holds_loaded? and @frozen_holds_count == 0}
              id="frozen-protection-holds-empty"
              class="px-3 py-6 text-center text-sm text-gray-400"
            >
              No open complaints.
            </div>
            <div
              :for={{id, hold} <- @streams.frozen_holds}
              id={id}
              data-selected={@selected_hold && @selected_hold.id == hold.id}
              class={[
                "rounded-[10px] transition-colors",
                if(@selected_hold && @selected_hold.id == hold.id,
                  do: "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <button
                type="button"
                phx-click="select_hold"
                phx-value-id={hold.id}
                class="w-full text-left px-3 py-2.5 flex items-start justify-between gap-3"
              >
                <span class="min-w-0">
                  <span class="block text-[13px] font-semibold text-gray-900 leading-tight truncate">
                    {"#{order_number(hold)} · #{store_name(hold)}"}
                  </span>
                  <span class="block text-[11.5px] font-medium text-rose-600 leading-tight mt-0.5 truncate">
                    {complaint_label(hold.complaint_reason)}
                  </span>
                </span>
                <span class="text-[12.5px] font-bold text-gray-900 tabular-nums shrink-0">
                  {money(hold.amount, hold_currency(hold))}
                </span>
              </button>
            </div>
          </div>

          <div class="px-4 pt-3 pb-1 border-t border-gray-100">
            <h2 class="text-[11px] font-bold uppercase tracking-wider text-amber-600">
              {"Stale — 30+ days · #{@stale_holds_count}"}
            </h2>
          </div>
          <div id="stale-protection-holds" phx-update="stream" class="px-2 pb-2">
            <div
              :if={!@holds_loaded?}
              id="stale-protection-holds-loading"
              class="px-3 py-6 text-center text-sm text-gray-400"
            >
              Loading…
            </div>
            <div
              :if={@holds_loaded? and @stale_holds_count == 0}
              id="stale-protection-holds-empty"
              class="px-3 py-6 text-center text-sm text-gray-400"
            >
              Nothing stale right now.
            </div>
            <div
              :for={{id, hold} <- @streams.stale_holds}
              id={id}
              data-selected={@selected_hold && @selected_hold.id == hold.id}
              class={[
                "rounded-[10px] transition-colors",
                if(@selected_hold && @selected_hold.id == hold.id,
                  do: "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <button
                type="button"
                phx-click="select_hold"
                phx-value-id={hold.id}
                class="w-full text-left px-3 py-2.5 flex items-start justify-between gap-3"
              >
                <span class="min-w-0">
                  <span class="block text-[13px] font-semibold text-gray-900 leading-tight truncate">
                    {"#{order_number(hold)} · #{store_name(hold)}"}
                  </span>
                  <span class="block text-[11.5px] font-medium text-amber-600 leading-tight mt-0.5 truncate">
                    {"Held #{days_held(hold)} days · no release timer"}
                  </span>
                </span>
                <span class="text-[12.5px] font-bold text-gray-900 tabular-nums shrink-0">
                  {money(hold.amount, hold_currency(hold))}
                </span>
              </button>
            </div>
          </div>
        </div>

        <%!-- Case panel --%>
        <div id="protection-panel" class="flex-1 min-w-0 w-full">
          <div
            :if={!@holds_loaded?}
            class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
          >
            Loading…
          </div>

          <.platform_empty_state
            :if={@holds_loaded? and is_nil(@selected_hold)}
            icon="hero-shield-check"
            title="All money is moving"
            description="No frozen or stale protection holds need a staff decision right now."
          />

          <div
            :if={@selected_hold}
            class="bg-white rounded-2xl border border-gray-200 shadow-sm p-6"
          >
            <div class="flex flex-wrap items-center gap-3">
              <p class="text-[26px] font-bold text-gray-900 tracking-tight tabular-nums leading-none">
                {money(@selected_hold.amount, hold_currency(@selected_hold))}
              </p>
              <.severity_pill
                :if={@selected_section == :frozen}
                label="Frozen — open complaint"
                tone="rose"
              />
              <.severity_pill
                :if={@selected_section == :stale}
                label="Stale — no release timer"
                tone="amber"
              />
            </div>

            <p class="text-[13px] text-gray-500 mt-2">
              {"Order #{order_number(@selected_hold)} · #{store_name(@selected_hold)} · Buyer #{buyer_phone(@selected_hold)} · Held since #{date_str(@selected_hold.inserted_at)}"}
            </p>

            <.link
              :if={PlatformPermissions.allowed?(@current_user, :manage_stores)}
              navigate={~p"/platform/stores/#{@selected_hold.store_id}"}
              class="inline-block mt-2 text-[13px] font-semibold text-blue-600 hover:text-blue-700"
            >
              Open store &rarr;
            </.link>

            <%!-- The whole hold, accounted for. The headline is `amount` and
                  the release button pays `net`; without the fee on screen those
                  read as two unexplained numbers for the same order. --%>
            <div class="mt-4 grid grid-cols-3 rounded-xl border border-gray-200 overflow-hidden">
              <div class="p-3.5 border-r border-gray-200">
                <p class="text-[12px] font-semibold text-gray-500">Buyer paid</p>
                <p class="text-[15px] font-bold text-gray-900 tabular-nums mt-1">
                  {money(@selected_hold.amount, hold_currency(@selected_hold))}
                </p>
              </div>
              <div class="p-3.5 border-r border-gray-200 bg-gray-50">
                <p class="text-[12px] font-semibold text-gray-500">Makola's share</p>
                <p class="text-[15px] font-bold text-gray-600 tabular-nums mt-1">
                  {money(@selected_hold.fee, hold_currency(@selected_hold))}
                </p>
              </div>
              <div class="p-3.5">
                <p class="text-[12px] font-semibold text-gray-500">Merchant would get</p>
                <p class="text-[15px] font-bold text-emerald-700 tabular-nums mt-1">
                  {money(@selected_hold.net, hold_currency(@selected_hold))}
                </p>
              </div>
            </div>

            <div
              :if={@selected_section == :frozen}
              class="mt-4 rounded-xl border border-rose-100 bg-rose-50 p-4"
            >
              <p class="text-[13px] font-bold text-rose-700">
                {complaint_label(@selected_hold.complaint_reason)}
              </p>
              <p :if={@selected_hold.complaint_text} class="text-[13px] text-rose-900/80 mt-1">
                {@selected_hold.complaint_text}
              </p>
            </div>

            <div
              :if={@selected_section == :stale}
              class="mt-4 rounded-xl border border-amber-100 bg-amber-50 p-4"
            >
              <p class="text-[13px] text-amber-800">
                {"Held #{days_held(@selected_hold)} days with no auto-release timer — the money is stuck until a staff decision."}
              </p>
            </div>

            <div class="grid sm:grid-cols-2 gap-3 mt-5">
              <div class="rounded-xl border border-gray-200 p-4">
                <h3 class="text-[13.5px] font-bold text-gray-900">Refund the buyer</h3>
                <p class="text-[12.5px] text-gray-500 mt-1">
                  {"Returns #{money(@selected_hold.amount, hold_currency(@selected_hold))} to the buyer's mobile money. The merchant is notified."}
                </p>
                <button
                  type="button"
                  phx-click="refund_buyer"
                  phx-value-id={@selected_hold.id}
                  data-confirm={"Refund #{money(@selected_hold.amount, hold_currency(@selected_hold))} to the buyer now? This cannot be undone."}
                  class="mt-3 px-4 py-2 rounded-lg text-[13px] font-semibold bg-rose-600 text-white hover:bg-rose-700"
                >
                  Refund buyer
                </button>
              </div>
              <div class="rounded-xl border border-gray-200 p-4">
                <h3 class="text-[13.5px] font-bold text-gray-900">Release to the merchant</h3>
                <p class="text-[12.5px] text-gray-500 mt-1">
                  {"Pays #{money(@selected_hold.net, hold_currency(@selected_hold))} to the merchant now and closes the hold."}
                </p>
                <button
                  type="button"
                  phx-click="force_release"
                  phx-value-id={@selected_hold.id}
                  data-confirm={"Release #{money(@selected_hold.net, hold_currency(@selected_hold))} to the merchant now? This cannot be undone."}
                  class="mt-3 px-4 py-2 rounded-lg text-[13px] font-semibold bg-emerald-600 text-white hover:bg-emerald-700"
                >
                  Force release
                </button>
              </div>
            </div>

            <p class="text-[12px] text-gray-400 mt-4">
              Both decisions are recorded in the platform audit log.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp order_number(hold), do: (hold.order && hold.order.order_number) || "—"

  defp store_name(hold), do: (hold.store && hold.store.name) || "—"

  defp days_held(hold) do
    Date.diff(Date.utc_today(), DateTime.to_date(hold.inserted_at))
  end

  defp complaint_label(:not_received), do: "Not received"
  defp complaint_label(:not_as_described), do: "Not as described"
  defp complaint_label(_), do: "Other"

  defp buyer_phone(hold) do
    hold.order
    |> case do
      %{shipping_address: %{"phone" => phone}} when is_binary(phone) -> phone
      _ -> nil
    end
    |> mask_phone()
  end

  defp mask_phone(phone) when is_binary(phone) and byte_size(phone) > 4 do
    visible = String.slice(phone, -4, 4)
    masked = String.duplicate("*", max(String.length(phone) - 4, 0))
    "#{masked}#{visible}"
  end

  defp mask_phone(_phone), do: "—"

  # The rows load `:order` (list_frozen/list_stale), so the hold's own
  # currency is right there — falls back to "GHS" only for the rare hold
  # whose order association didn't load.
  defp hold_currency(hold) do
    case hold.order do
      %{currency: currency} when is_binary(currency) -> currency
      _ -> "GHS"
    end
  end

  # Held money, summed PER CURRENCY. Adding GHS to NGN and labelling the
  # result "GHS" is the bug this page's own currency test guards against;
  # a mixed queue reads "GHS 400.00 · NGN 250.00".
  defp total_held([]), do: money(0, "GHS")

  defp total_held(holds) do
    holds
    |> Enum.group_by(&hold_currency/1, &(&1.amount || 0))
    |> Enum.map(fn {currency, amounts} -> money(Enum.sum(amounts), currency) end)
    |> Enum.sort()
    |> Enum.join(" · ")
  end

  defp oldest_days([]), do: nil

  defp oldest_days(holds) do
    holds
    |> Enum.map(&days_held/1)
    |> Enum.max(fn -> nil end)
  end

  defp oldest_label(nil), do: "—"
  defp oldest_label(1), do: "1 day"
  defp oldest_label(days), do: "#{days} days"

  defp money(nil, currency), do: "#{currency} 0.00"

  defp money(cents, currency) when is_integer(cents) do
    major = cents |> div(100) |> Emakola.Money.group_thousands()
    "#{currency} #{major}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
  end

  defp date_str(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(_), do: "—"
end
