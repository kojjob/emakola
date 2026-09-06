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
    count = AbandonedCheckouts.count_left_behind(store.id)

    {:ok,
     socket
     |> assign(
       page_title: "Carts left behind",
       active_nav: :orders,
       store: store,
       carts_count: count
     )
     |> stream(:carts, AbandonedCheckouts.left_behind(store.id), dom_id: &"cart-#{&1.id}")}
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
        :if={@carts_count == 0}
        icon="hero-shopping-cart"
        tone={:info}
        title="No carts left behind"
        description="Buyers who stop after typing a phone appear here after two hours"
      />

      <div :if={@carts_count > 0} class="space-y-3">
        <p :if={@carts_count > AbandonedCheckouts.list_limit()} class="text-xs text-slate-400">
          Showing the newest {AbandonedCheckouts.list_limit()}
        </p>

        <div id="carts" phx-update="stream" class="space-y-3">
          <div
            :for={{dom_id, cart} <- @streams.carts}
            id={dom_id}
            class="bg-white rounded-2xl shadow-sm p-5 flex flex-wrap items-start justify-between gap-4"
          >
            <div class="min-w-0">
              <p class="font-semibold text-slate-900">{display_name(cart)}</p>
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
    </div>
    """
  end

  # A buyer-typed name is free text; 60 characters keeps a long one from
  # blowing out the card layout. The stored value is separately capped at
  # 255 (Emakola.Orders.AbandonedCheckouts.touch/3) — this is a display
  # limit, not a storage one.
  defp display_name(cart) do
    (cart.name || cart.phone) |> String.slice(0, 60)
  end

  defp ago(at) do
    hours = div(DateTime.diff(DateTime.utc_now(), at, :second), 3600)

    cond do
      hours < 24 -> "#{hours} hours ago"
      true -> "#{div(hours, 24)} days ago"
    end
  end
end
