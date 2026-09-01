defmodule EmakolaWeb.Admin.SupplyNetworkLive.ActivationComponents do
  @moduledoc false

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  attr :delivery_form, :any, required: true
  attr :delivery_fulfillment_id, :any, required: true
  attr :first_money, :map, required: true
  attr :inbound_count, :integer, required: true
  attr :sales_click_count, :integer, required: true
  attr :sales_order_count, :integer, required: true
  attr :sales_revenue, :integer, required: true
  attr :shipping_form, :any, required: true
  attr :shipping_fulfillment_id, :any, required: true
  attr :streams, :map, required: true

  def activation(assigns) do
    ~H"""
    <div
      id="earn-activation-grid"
      aria-labelledby="first-money-heading"
      class="grid gap-5 lg:grid-cols-[0.9fr_1.4fr]"
    >
      <section
        id="first-money-journey"
        class="rounded-3xl border border-emerald-200 bg-gradient-to-br from-emerald-50 to-white p-6 shadow-sm sm:p-7"
      >
        <span class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">
          First Money journey
        </span>
        <h2 id="first-money-heading" class="mt-2 text-2xl font-bold tracking-tight text-slate-950">
          Your path to the first fulfilled sale
        </h2>
        <p class="mt-2 text-sm leading-6 text-slate-600">
          Focus on one next action at a time. Makola updates this automatically from real activity.
        </p>

        <ol id="first-money-steps" class="mt-6 space-y-3">
          <li
            :for={
              step <- [
                journey_step(@first_money, :connected, "Connect", "Agree with a supplier"),
                journey_step(@first_money, :listed, "List", "Add one product to your store"),
                journey_step(@first_money, :shared, "Share", "Send a tracked sales link"),
                journey_step(@first_money, :sold, "Sell", "Receive a confirmed attributed order"),
                journey_step(
                  @first_money,
                  :fulfilled,
                  "Fulfill",
                  "Complete delivery to the customer"
                )
              ]
            }
            id={"first-money-step-#{step.key}"}
            data-complete={to_string(step.complete?)}
            class="flex items-start gap-3"
          >
            <span class={[
              "mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full ring-1 ring-inset",
              if(step.complete?,
                do: "bg-emerald-600 text-white ring-emerald-600",
                else: "bg-white text-slate-300 ring-slate-200"
              )
            ]}>
              <.icon
                name={if(step.complete?, do: "hero-check", else: "hero-ellipsis-horizontal")}
                class="size-4"
              />
            </span>
            <div>
              <p class={[
                "text-sm font-bold",
                if(step.complete?, do: "text-emerald-800", else: "text-slate-700")
              ]}>
                {step.label}
              </p>
              <p class="text-xs text-slate-500">{step.description}</p>
            </div>
          </li>
        </ol>
      </section>

      <section
        id="sales-kit-panel"
        class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-7"
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-600">
              Sales Kits
            </span>
            <h2 class="mt-2 text-xl font-bold text-slate-950">Ready-to-share product links</h2>
            <p class="mt-1 text-sm text-slate-500">
              Use the Sales kit button beside an imported product. Every link tracks genuine interest and confirmed orders.
            </p>
          </div>
          <div class="grid grid-cols-3 gap-2 text-center">
            <div class="rounded-xl bg-slate-50 px-3 py-2">
              <p id="sales-click-count" class="text-sm font-bold text-slate-900">
                {@sales_click_count}
              </p>
              <p class="text-[10px] uppercase text-slate-400">Clicks</p>
            </div>
            <div class="rounded-xl bg-slate-50 px-3 py-2">
              <p id="sales-order-count" class="text-sm font-bold text-slate-900">
                {@sales_order_count}
              </p>
              <p class="text-[10px] uppercase text-slate-400">Orders</p>
            </div>
            <div class="rounded-xl bg-emerald-50 px-3 py-2">
              <p id="sales-revenue" class="text-sm font-bold text-emerald-800">
                {money(@sales_revenue)}
              </p>
              <p class="text-[10px] uppercase text-emerald-600">Sales</p>
            </div>
          </div>
        </div>

        <div id="sales-shares" phx-update="stream" class="mt-5 grid gap-3 sm:grid-cols-2">
          <div
            id="sales-shares-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-8 text-center sm:col-span-2"
          >
            <.icon name="hero-megaphone" class="mx-auto size-8 text-slate-300" />
            <p class="mt-2 text-sm font-semibold text-slate-700">Create your first Sales Kit</p>
            <p class="mt-1 text-xs text-slate-500">
              Choose an imported product above to generate channel-ready links.
            </p>
          </div>

          <article
            :for={{dom_id, share} <- @streams.sales_shares}
            id={dom_id}
            class="rounded-2xl border border-slate-200 p-4 transition hover:border-violet-200 hover:shadow-sm"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex min-w-0 items-center gap-3">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-violet-700">
                  <.icon name={channel_icon(share.channel)} class="size-4" />
                </span>
                <div class="min-w-0">
                  <p class="truncate text-sm font-bold text-slate-900">{share.product.title}</p>
                  <p class="text-xs text-slate-500">{channel_label(share.channel)}</p>
                </div>
              </div>
              <span class="text-[10px] font-semibold text-slate-400">
                {Emakola.Plural.count(share.click_count, "click")} · {Emakola.Plural.count(
                  share.order_count,
                  "order"
                )}
              </span>
            </div>

            <%= case share.channel do %>
              <% :whatsapp -> %>
                <a
                  id={"share-whatsapp-#{share.id}"}
                  href={whatsapp_share_url(share)}
                  target="_blank"
                  rel="noopener"
                  phx-click="record_sales_share"
                  phx-value-id={share.id}
                  class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700"
                >
                  <.icon name="hero-chat-bubble-left-right" class="size-4" /> Share on WhatsApp
                </a>
              <% :facebook -> %>
                <a
                  id={"share-facebook-#{share.id}"}
                  href={facebook_share_url(share)}
                  target="_blank"
                  rel="noopener"
                  phx-click="record_sales_share"
                  phx-value-id={share.id}
                  class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-blue-700"
                >
                  <.icon name="hero-user-group" class="size-4" /> Share on Facebook
                </a>
              <% :copy_link -> %>
                <button
                  id={"copy-sales-link-#{share.id}"}
                  type="button"
                  phx-hook=".CopySalesLink"
                  phx-click="record_sales_share"
                  phx-value-id={share.id}
                  data-url={sales_share_url(share)}
                  class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-violet-700"
                >
                  <.icon name="hero-link" class="size-4" /> Copy sales link
                </button>
            <% end %>
          </article>
        </div>
      </section>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopySalesLink">
      export default {
        mounted() {
          this.el.addEventListener("click", () => navigator.clipboard.writeText(this.el.dataset.url))
        }
      }
    </script>

    <section id="supplier-inbox" aria-labelledby="supplier-inbox-heading" class="space-y-5">
      <div class="overflow-hidden rounded-3xl bg-gradient-to-br from-slate-950 to-slate-800 px-6 py-7 text-white shadow-lg sm:px-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <span class="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.18em] text-emerald-300">
              <.icon name="hero-inbox-stack" class="size-4" /> Supplier inbox
            </span>
            <h2 id="supplier-inbox-heading" class="mt-2 text-2xl font-bold tracking-tight">
              Orders for you to fulfill
            </h2>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
              These orders were sold by connected Makola stores using your products. Ship directly to the customer, then use their private code as delivery proof.
            </p>
          </div>
          <span
            id="inbound-fulfillment-count"
            class="w-fit rounded-full bg-white/10 px-3 py-1.5 text-xs font-bold text-white ring-1 ring-white/15"
          >
            {Emakola.Plural.count(@inbound_count, "order")}
          </span>
        </div>
      </div>

      <div id="inbound-fulfillments" phx-update="stream" class="space-y-4">
        <div
          id="inbound-empty"
          class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"
        >
          <.icon name="hero-truck" class="mx-auto size-9 text-slate-300" />
          <p class="mt-3 text-sm font-semibold text-slate-700">No partner orders need attention</p>
          <p class="mt-1 text-xs text-slate-500">
            New paid orders for your shared products will appear here.
          </p>
        </div>

        <article
          :for={{dom_id, fulfillment} <- @streams.inbound_fulfillments}
          id={dom_id}
          class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <div class="flex flex-wrap items-center gap-2">
                <h3 class="font-bold text-slate-900">Order {fulfillment.order.order_number}</h3>
                <span class={[
                  "rounded-full px-2.5 py-1 text-[11px] font-bold capitalize",
                  fulfillment_status_classes(fulfillment.status)
                ]}>
                  {fulfillment.status}
                </span>
              </div>
              <p class="mt-1 text-xs text-slate-500">
                Sold by {fulfillment.supplier.name} · Deliver to {customer_city(fulfillment.order)}
              </p>
            </div>
            <p class="text-xs font-semibold text-slate-400">
              {Emakola.Plural.count(length(fulfillment.line_items), "item type")}
            </p>
          </div>

          <ul class="mt-4 divide-y divide-slate-100 rounded-xl bg-slate-50 px-4">
            <li
              :for={item <- fulfillment.line_items}
              class="flex items-center justify-between gap-4 py-3 text-sm"
            >
              <span class="font-medium text-slate-700">{item.product_title}</span>
              <span class="shrink-0 text-xs font-bold text-slate-500">× {item.quantity}</span>
            </li>
          </ul>

          <div class="mt-4 flex flex-wrap items-center gap-2">
            <button
              :if={fulfillment.status in [:pending, :notified]}
              id={"prepare-shipment-#{fulfillment.id}"}
              phx-click="select_inbound_shipping"
              phx-value-id={fulfillment.id}
              class="rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700 active:scale-[0.98]"
            >
              Mark shipped
            </button>
            <button
              :if={fulfillment.status == :shipped}
              id={"send-delivery-code-#{fulfillment.id}"}
              phx-click="request_delivery_code"
              phx-value-id={fulfillment.id}
              class="rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-700 active:scale-[0.98]"
            >
              {if fulfillment.delivery_proof, do: "Send new code", else: "Send delivery code"}
            </button>
            <button
              :if={fulfillment.status == :shipped and fulfillment.delivery_proof}
              id={"enter-delivery-code-#{fulfillment.id}"}
              phx-click="enter_delivery_code"
              phx-value-id={fulfillment.id}
              class="rounded-xl border border-slate-200 px-4 py-2.5 text-xs font-bold text-slate-700 transition hover:bg-slate-50"
            >
              Enter customer code
            </button>
            <span
              :if={fulfillment.status == :delivered}
              class="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-700"
            >
              <.icon name="hero-check-circle" class="size-4" /> Customer confirmed delivery
            </span>
          </div>

          <.form
            :if={shipment_open?(fulfillment.id, @shipping_fulfillment_id)}
            for={@shipping_form}
            id={"ship-inbound-form-#{fulfillment.id}"}
            phx-submit="ship_inbound"
            class="mt-4 flex flex-col gap-3 rounded-xl border border-slate-200 bg-slate-50 p-4 sm:flex-row sm:items-end"
          >
            <div class="flex-1">
              <.input
                field={@shipping_form[:tracking_number]}
                type="text"
                label="Tracking number"
                placeholder="Optional courier reference"
              />
            </div>
            <div class="flex gap-2 pb-0.5">
              <button
                type="submit"
                class="rounded-xl bg-slate-950 px-4 py-2.5 text-xs font-bold text-white"
              >
                Confirm shipment
              </button>
              <button
                type="button"
                phx-click="cancel_inbound_shipping"
                class="rounded-xl px-3 py-2.5 text-xs font-bold text-slate-500"
              >
                Cancel
              </button>
            </div>
          </.form>

          <.form
            :if={delivery_open?(fulfillment.id, @delivery_fulfillment_id)}
            for={@delivery_form}
            id={"verify-delivery-form-#{fulfillment.id}"}
            phx-submit="verify_delivery"
            class="mt-4 flex flex-col gap-3 rounded-xl border border-emerald-200 bg-emerald-50/60 p-4 sm:flex-row sm:items-end"
          >
            <div class="flex-1">
              <.input
                field={@delivery_form[:code]}
                type="text"
                inputmode="numeric"
                pattern="[0-9]{6}"
                maxlength="6"
                label="Customer's 6-digit code"
                placeholder="000000"
                required
              />
            </div>
            <button
              type="submit"
              class="rounded-xl bg-emerald-700 px-4 py-2.5 text-xs font-bold text-white transition hover:bg-emerald-800"
            >
              Confirm delivery
            </button>
          </.form>
        </article>
      </div>
    </section>
    """
  end
end
