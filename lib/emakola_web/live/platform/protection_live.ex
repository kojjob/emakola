defmodule EmakolaWeb.Platform.ProtectionLive do
  @moduledoc """
  Platform staff buyer-protection queue (TC-2 Task 12): frozen holds (an
  open buyer complaint) and stale holds (`:held`, never started the
  auto-release timer, 30+ days old) needing manual review.

  Gated by RequirePermission(:manage_billing) — the same permission as the
  rest of the money surfaces (Billing/Finance/Payments/Refunds). No DB
  queries in disconnected mount.

  Two actions per row, both re-checking :manage_billing against a freshly
  reloaded user before acting and writing a `Emakola.Accounts.PlatformAudit`
  entry on success:

    * Force release — `ProtectionRelease.release(hold, :staff, respect_freeze:
      false)`. A frozen hold additionally gets `resolution:
      :released_by_staff`, stamped inside `ProtectionRelease` itself once it
      reads `frozen_at` off the FOR UPDATE-locked row.
    * Refund buyer — a full refund through the SAME `RefundService` the
      merchant returns flow uses, creating a `Return` for the order first
      (staff-initiated, no prior customer return request needed) and passing
      `resolution: :refunded_by_staff, authorize?: false` (the platform staff
      actor has no Ash policy grant on `Return`/`Payment`). The hold does
      NOT close synchronously — only the refund webhook's terminal
      confirmation closes it (see `RefundService`'s "Buyer-protection hold"
      section) — so the flash says "initiated", not "refunded", and the row
      stays in the queue until the webhook lands.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.ProtectionRelease
  alias Emakola.Payments.RefundService

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Buyer Protection")
      |> assign(:active_nav, :protection)
      |> assign(:frozen_holds, nil)
      |> assign(:stale_holds, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
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
    with {:ok, return} <- find_or_create_return(hold) do
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
  # protection queue — reuse one if the buyer already filed it, otherwise
  # create it (staff-initiated, mirrors how ModerationLive bypasses the
  # ordinary merchant-only actions with `authorize?: false`).
  defp find_or_create_return(hold) do
    case Emakola.Orders.get_return_by_order(hold.order_id, authorize?: false) do
      {:ok, [%{status: :requested} = return | _]} ->
        {:ok, return}

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

  defp refund_error(:amount_exceeds_refundable),
    do: "This payment has a smaller refundable balance than the hold — check for a prior refund."

  defp refund_error(:gateway_unsupported),
    do: "This gateway has no refund API — issue it in the provider's dashboard."

  defp refund_error(:payment_not_found),
    do: "No payment was found for this order, so there is nothing to refund."

  defp refund_error(_reason), do: "Could not initiate the refund."

  defp find_hold(socket, id) do
    Enum.find(
      (socket.assigns.frozen_holds || []) ++ (socket.assigns.stale_holds || []),
      &(&1.id == id)
    )
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
    socket
    |> assign(:frozen_holds, ProtectionHolds.list_frozen())
    |> assign(:stale_holds, ProtectionHolds.list_stale())
  rescue
    exception ->
      Logger.error("[platform.protection_live] load raised: #{Exception.message(exception)}")

      socket
      |> assign(:frozen_holds, [])
      |> assign(:stale_holds, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-6xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Buyer Protection</h1>
        <p class="text-sm text-gray-500 mt-1">
          Frozen holds (open complaints) and stale holds (30+ days, no auto-release timer) across all stores.
        </p>
      </div>

      <section class="mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-3">Frozen — open complaints</h2>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Order</th>
                <th class="px-6 py-3">Store</th>
                <th class="px-6 py-3">Buyer</th>
                <th class="px-6 py-3">Complaint</th>
                <th class="px-6 py-3">Amount</th>
                <th class="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr :if={is_nil(@frozen_holds)}>
                <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">Loading…</td>
              </tr>
              <tr :if={@frozen_holds == []}>
                <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">
                  No open complaints.
                </td>
              </tr>
              <tr :for={hold <- @frozen_holds || []} class="hover:bg-gray-50 transition-colors">
                <td class="px-6 py-4 text-sm font-medium text-gray-900">
                  {(hold.order && hold.order.order_number) || "—"}
                </td>
                <td class="px-6 py-4 text-sm text-gray-600">
                  {(hold.store && hold.store.name) || "—"}
                </td>
                <td class="px-6 py-4 text-sm text-gray-600 font-mono">{buyer_phone(hold)}</td>
                <td class="px-6 py-4 text-sm text-gray-700 max-w-xs">
                  <p class="font-medium">{complaint_label(hold.complaint_reason)}</p>
                  <p :if={hold.complaint_text} class="text-xs text-gray-500 truncate">
                    {hold.complaint_text}
                  </p>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900 tabular-nums">{money(hold.amount)}</td>
                <td class="px-6 py-4 text-right whitespace-nowrap">
                  <.hold_actions hold={hold} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 class="text-lg font-semibold text-gray-900 mb-3">Stale — 30+ days, no release timer</h2>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Order</th>
                <th class="px-6 py-3">Store</th>
                <th class="px-6 py-3">Buyer</th>
                <th class="px-6 py-3">Held since</th>
                <th class="px-6 py-3">Amount</th>
                <th class="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr :if={is_nil(@stale_holds)}>
                <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">Loading…</td>
              </tr>
              <tr :if={@stale_holds == []}>
                <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">
                  Nothing stale right now.
                </td>
              </tr>
              <tr :for={hold <- @stale_holds || []} class="hover:bg-gray-50 transition-colors">
                <td class="px-6 py-4 text-sm font-medium text-gray-900">
                  {(hold.order && hold.order.order_number) || "—"}
                </td>
                <td class="px-6 py-4 text-sm text-gray-600">
                  {(hold.store && hold.store.name) || "—"}
                </td>
                <td class="px-6 py-4 text-sm text-gray-600 font-mono">{buyer_phone(hold)}</td>
                <td class="px-6 py-4 text-sm text-gray-500">{date_str(hold.inserted_at)}</td>
                <td class="px-6 py-4 text-sm text-gray-900 tabular-nums">{money(hold.amount)}</td>
                <td class="px-6 py-4 text-right whitespace-nowrap">
                  <.hold_actions hold={hold} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
    """
  end

  attr :hold, :map, required: true

  defp hold_actions(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="force_release"
      phx-value-id={@hold.id}
      data-confirm={"Release #{money(@hold.net)} to the merchant now? This cannot be undone."}
      class="px-3 py-1.5 rounded-lg text-xs font-medium bg-emerald-100 text-emerald-700 hover:bg-emerald-200"
    >
      Force release
    </button>
    <button
      type="button"
      phx-click="refund_buyer"
      phx-value-id={@hold.id}
      data-confirm={"Refund #{money(@hold.amount)} to the buyer now? This cannot be undone."}
      class="ml-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-red-100 text-red-700 hover:bg-red-200"
    >
      Refund buyer
    </button>
    """
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

  defp money(nil), do: "GHS 0.00"

  defp money(cents) when is_integer(cents) do
    major = cents |> div(100) |> Emakola.Money.group_thousands()
    "GHS #{major}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
  end

  defp date_str(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(_), do: "—"
end
