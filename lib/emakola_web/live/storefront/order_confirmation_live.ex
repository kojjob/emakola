defmodule EmakolaWeb.Storefront.OrderConfirmationLive do
  @moduledoc """
  Order confirmation page with celebration design and delivery timeline.

  Displays:
  - Animated success checkmark
  - "You're all set!" heading with order number
  - "What happens next" vertical timeline
  - Compact order summary with expandable details
  - Continue shopping + WhatsApp contact CTAs
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def mount(%{"store_slug" => slug, "order_number" => order_number}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        categories =
          try do
            Emakola.Catalog.list_root_categories!(store.id)
          rescue
            _ -> []
          end

        case load_order(store, order_number) do
          {:ok, order} ->
            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:categories, categories)
             |> assign(:order, order)
             |> assign(:cart, [])
             |> assign(:cart_count, 0)
             |> assign(:show_details, false)
             |> assign(:page_title, "Order #{order.order_number} - #{store.name}")}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Order not found")
             |> redirect(to: "/s/#{slug}")}
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
    {:noreply, assign(socket, :show_details, !socket.assigns.show_details)}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :order_confirmation) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.OrderConfirmation.render(assigns)
    end
  end

  # -- Data Loading --

  defp load_order(store, order_number) do
    case Emakola.Orders.Order
         |> Ash.Query.for_read(:get_by_order_number, %{
           order_number: order_number,
           store_id: store.id
         })
         |> Ash.Query.load(line_items: [variant: [product: [:images]]])
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, order} -> {:ok, order}
      {:error, _} -> {:error, :not_found}
    end
  end
end
