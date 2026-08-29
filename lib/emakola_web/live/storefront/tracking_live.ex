defmodule EmakolaWeb.Storefront.TrackingLive do
  @moduledoc """
  Delivery tracking page — shows order status timeline, rider info,
  map placeholder, and collapsible order details.

  Loads real order data from the database and maps the order status
  to a visual timeline.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  require Logger

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.TrackingTokens
  alias Emakola.Payments.ProtectionHolds

  @impl true
  def mount(%{"order_number" => order_number} = params, _session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case load_order(store, order_number) do
          {:ok, order} ->
            tracking = build_tracking_data(order)
            categories = load_root_categories(store)
            protection_hold = ProtectionHolds.get_hold_for_order(order.id, store.id)
            buyer_authorized? = buyer_authorized?(params["t"], order.id)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:order_number, order_number)
             |> assign(:order, order)
             |> assign(:tracking, tracking)
             |> assign(:categories, categories)
             |> assign(:cart_count, 0)
             |> assign(:details_open, false)
             |> assign(:protection_hold, protection_hold)
             |> assign(:buyer_authorized?, buyer_authorized?)
             |> assign(:complaint_form_open, false)
             |> assign(:page_title, "Track Order ##{order_number} - #{store.name}")}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Order not found")
             |> redirect(to: store_path(slug, "/"))}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :details_open, !socket.assigns.details_open)}
  end

  # Re-checks `buyer_authorized?` from assigns (defense in depth) rather than
  # trusting mount-time authorization alone — the core TC-2 invariant: the
  # merchant also knows the order number, so a bare tracking URL must never
  # move money. Only a token that verifies AND matches THIS order authorizes.
  @impl true
  def handle_event("confirm_received", _params, socket) do
    %{buyer_authorized?: buyer_authorized?, order: order, store: store} = socket.assigns

    if buyer_authorized? do
      case ProtectionHolds.release_for_order(order.id, store.id, :buyer_confirmed) do
        :ok ->
          hold = ProtectionHolds.get_hold_for_order(order.id, store.id)

          {:noreply,
           socket
           |> assign(:protection_hold, hold)
           |> flash_confirm_outcome(hold)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not confirm delivery. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_complaint", _params, socket) do
    if socket.assigns.buyer_authorized? do
      {:noreply, assign(socket, :complaint_form_open, !socket.assigns.complaint_form_open)}
    else
      {:noreply, socket}
    end
  end

  # Complaint UI shell (TC-2 Task 7/8): files the freeze via the
  # ProtectionHold `:freeze` domain interface (Task 3). A hold already
  # frozen by an earlier complaint routes to `:update_complaint` instead
  # (Task 3) — `:freeze` only succeeds once (`validate(absent(:frozen_at))`),
  # so re-filing without this branch would error. Both actions leave the
  # hold as a single row — re-filing updates the existing complaint's
  # reason/text rather than creating a new one.
  @impl true
  def handle_event("file_complaint", %{"reason" => reason, "text" => text}, socket) do
    %{buyer_authorized?: buyer_authorized?, order: order, store: store} = socket.assigns

    if buyer_authorized? do
      case ProtectionHolds.get_hold_for_order(order.id, store.id) do
        nil ->
          {:noreply, socket}

        hold ->
          complaint_reason =
            Emakola.SafeAtom.to_atom_in(
              reason,
              [:not_received, :not_as_described, :other],
              :other
            )

          attrs = %{complaint_reason: complaint_reason, complaint_text: String.trim(text)}

          result =
            if hold.frozen_at do
              Emakola.Payments.update_complaint_protection_hold(hold, attrs, authorize?: false)
            else
              Emakola.Payments.freeze_protection_hold(hold, attrs, authorize?: false)
            end

          case result do
            {:ok, updated_hold} ->
              # Only a NEW complaint (hold wasn't already frozen) notifies the
              # merchant — re-filing via :update_complaint must not re-fire it.
              if is_nil(hold.frozen_at) do
                Emakola.Notifications.Dispatcher.dispatch(
                  %{id: order.id, store_id: store.id},
                  :protection_complaint
                )
              end

              {:noreply,
               socket
               |> assign(:protection_hold, updated_hold)
               |> assign(:complaint_form_open, false)
               |> put_flash(
                 :info,
                 "Complaint received — the payment stays held while we review it."
               )}

            {:error, _error} ->
              {:noreply,
               put_flash(socket, :error, "Could not file your complaint. Please try again.")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  # A page that does not know an event is a bug in whatever sent it — a theme
  # calling `add_to_bag` where this page listens for `add_to_cart`. Raising
  # takes the storefront down in front of a shopper mid-purchase, which is a
  # far worse answer than ignoring the click. Logged rather than swallowed
  # silently, so the next wrong event name does not ship unnoticed.
  def handle_event(event, _params, socket) do
    Logger.warning("[storefront] #{inspect(__MODULE__)} ignored unknown event #{inspect(event)}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :tracking) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Tracking.render(assigns)
    end
  end

  # -- Data Loading --

  defp load_order(store, order_number) do
    case Emakola.Orders.Order
         |> Ash.Query.for_read(:get_by_order_number, %{
           order_number: order_number,
           store_id: store.id
         })
         |> Ash.Query.load([:line_items])
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, order} -> {:ok, order}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp load_root_categories(store) do
    try do
      Emakola.Catalog.list_root_categories!(store.id)
    rescue
      exception ->
        Logger.error(
          "[tracking_live] load_root_categories loading root categories raised: #{Exception.message(exception)}"
        )

        []
    end
  end

  # -- Render data builders (called from mount) --

  defp build_tracking_data(order) do
    current_step = status_to_step(order.status)
    placed_time = format_time(order.inserted_at)
    updated_time = format_time(order.updated_at)

    timeline = [
      %{
        title: "Order Placed",
        subtitle: "Order ##{order.order_number}",
        time: placed_time
      },
      %{
        title: "Confirmed",
        subtitle: "Payment verified",
        time: if(current_step >= 1, do: updated_time)
      },
      %{
        title: "Being Prepared",
        subtitle: "Seller is preparing your order",
        time: if(current_step >= 2, do: updated_time)
      },
      %{
        title: "Shipped",
        subtitle: "On the way to you",
        time: if(current_step >= 3, do: updated_time)
      },
      %{
        title: "Delivered",
        subtitle: nil,
        time: if(current_step >= 4, do: updated_time)
      }
    ]

    %{current_step: current_step, timeline: timeline}
  end

  defp status_to_step(:pending), do: 0
  defp status_to_step(:confirmed), do: 1
  defp status_to_step(:processing), do: 2
  defp status_to_step(:shipped), do: 3
  defp status_to_step(:delivered), do: 4
  defp status_to_step(:cancelled), do: 0
  defp status_to_step(_), do: 0

  defp format_time(nil), do: nil

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  # Token must both verify AND match THIS order — a token signed for a
  # different order (valid signature, wrong order_id) does NOT authorize.
  defp buyer_authorized?(token, order_id) when is_binary(token) do
    match?({:ok, ^order_id}, TrackingTokens.verify_order_tracking(token))
  end

  defp buyer_authorized?(_token, _order_id), do: false

  defp flash_confirm_outcome(socket, %{status: :held, frozen_at: frozen_at})
       when not is_nil(frozen_at) do
    put_flash(
      socket,
      :info,
      "Your complaint is under review — the payment stays held until it's resolved."
    )
  end

  defp flash_confirm_outcome(socket, %{status: :released}) do
    put_flash(socket, :info, "Thanks for confirming — the seller has been paid.")
  end

  defp flash_confirm_outcome(socket, _hold), do: socket
end
