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

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  require Logger

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def mount(%{"order_number" => order_number}, _session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        categories =
          try do
            Emakola.Catalog.list_root_categories!(store.id)
          rescue
            exception ->
              Logger.error(
                "[order_confirmation_live] mount loading root categories raised: #{Exception.message(exception)}"
              )

              []
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
    {:noreply, assign(socket, :show_details, !socket.assigns.show_details)}
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
