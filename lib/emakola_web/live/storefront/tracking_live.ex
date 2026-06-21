defmodule EmakolaWeb.Storefront.TrackingLive do
  @moduledoc """
  Delivery tracking page — shows order status timeline, rider info,
  map placeholder, and collapsible order details.

  Loads real order data from the database and maps the order status
  to a visual timeline.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def mount(%{"store_slug" => slug, "order_number" => order_number}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case load_order(store, order_number) do
          {:ok, order} ->
            tracking = build_tracking_data(order)
            categories = load_root_categories(store)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:order_number, order_number)
             |> assign(:order, order)
             |> assign(:tracking, tracking)
             |> assign(:categories, categories)
             |> assign(:cart_count, 0)
             |> assign(:details_open, false)
             |> assign(:page_title, "Track Order ##{order_number} - #{store.name}")}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Order not found")
             |> redirect(to: "/@#{slug}")}
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
      _ -> []
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
end
