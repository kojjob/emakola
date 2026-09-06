defmodule EmakolaWeb.Admin.CartLive do
  @moduledoc """
  Carts left behind: buyers who typed a phone and did not finish. One
  WhatsApp link each. Nothing is sent from here.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  alias Emakola.Orders.AbandonedCheckouts

  @impl true
  def mount(_params, _session, %{assigns: %{current_store: nil}} = socket) do
    {:ok, push_navigate(socket, to: "/onboarding")}
  end

  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    {:ok,
     assign(socket,
       page_title: "Carts left behind",
       active_nav: :orders,
       store: store,
       carts: AbandonedCheckouts.left_behind(store.id)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1100px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        icon="hero-shopping-cart"
        title="Carts left behind"
        subtitle="They typed a phone, then stopped. One message brings most of them back."
      />

      <.empty_state
        :if={@carts == []}
        icon="hero-shopping-cart"
        tone={:info}
        title="No carts left behind"
        description="Buyers who stop after typing a phone appear here after two hours"
      />

      <div :if={@carts != []} class="space-y-3">
        <div
          :for={cart <- @carts}
          id={"cart-#{cart.id}"}
          class="bg-white rounded-2xl shadow-sm p-5 flex flex-wrap items-start justify-between gap-4"
        >
          <div class="min-w-0">
            <p class="font-semibold text-slate-900">{cart.name || cart.phone}</p>
            <p class="text-sm text-slate-500">{cart.phone}</p>
            <p class="text-sm text-slate-700 mt-2">
              {Enum.map_join(cart.items, ", ", &"#{&1["quantity"]} x #{&1["title"]}")}
            </p>
            <p class="text-xs text-slate-400 mt-1">Left {ago(cart.last_seen_at)}</p>
          </div>
          <div class="flex items-center gap-3 shrink-0">
            <span class="font-mono font-bold text-slate-900">{format_price(cart.cart_total)}</span>
            <a
              href={AbandonedCheckouts.whatsapp_url(cart, @store)}
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-xl text-sm font-semibold hover:bg-emerald-700 transition-colors"
            >
              <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> WhatsApp them
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp ago(at) do
    hours = div(DateTime.diff(DateTime.utc_now(), at, :second), 3600)

    cond do
      hours < 24 -> "#{hours} hours ago"
      true -> "#{div(hours, 24)} days ago"
    end
  end
end
