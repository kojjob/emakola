defmodule EmakolaWeb.Admin.SupplyNetworkLive.Components do
  @moduledoc """
  The Partners page as a hub: four numbers, the First Money strip, the
  partners list, what is waiting to be shipped, sales kits, and one door
  per Earn tool. `workbench/1` is the full set of tool sections, reached
  from the doors at `/admin/settings/supply-network/tools`.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  alias EmakolaWeb.Admin.SupplyNetworkLive.{
    ActivationComponents,
    CatalogComponents,
    CollaborationComponents,
    GoalComponents,
    OpportunityComponents
  }

  alias EmakolaWeb.Helpers.Currency

  @tools_path "/admin/settings/supply-network/tools"

  @journey [
    {:connected, "Connect", "Agree with a supplier"},
    {:listed, "List", "Add one product"},
    {:shared, "Share", "Send a sales link"},
    {:sold, "Sell", "Get an order"},
    {:fulfilled, "Fulfil", "Deliver it"}
  ]

  def page(assigns) do
    assigns = assign(assigns, :tools_path, @tools_path)

    ~H"""
    <div id="supply-network-page" class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header icon="hero-users" title="Partners" subtitle="Earn without buying stock">
        <.link
          navigate={~p"/admin/supply/catalog"}
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
        >
          <.icon name="hero-magnifying-glass" class="size-4" /> Browse suppliers
        </.link>
        <a
          href="#supply-connection-form"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors"
        >
          <.icon name="hero-plus" class="size-4" /> Invite a store
        </a>
      </.admin_page_header>

      <.hub_tiles
        connections={@connections}
        current_store={@current_store}
        connection_count={@connection_count}
        listing_count={@listing_count}
        low_stock_listing_count={@low_stock_listing_count}
        sales_revenue={@sales_revenue}
        sales_order_count={@sales_order_count}
        sales_click_count={@sales_click_count}
        inbound_count={@inbound_count}
      />

      <.journey_strip first_money={@first_money} tools_path={@tools_path} />

      <div class="grid grid-cols-1 xl:grid-cols-[minmax(0,1.55fr)_minmax(0,1fr)] gap-5 items-start">
        <.partners_card
          streams={@streams}
          current_store={@current_store}
          connection_count={@connection_count}
          connections={@connections}
          partner_stats={@partner_stats}
          form={@form}
        />
        <div class="flex flex-col gap-5">
          <.inbound_card
            inbound_count={@inbound_count}
            inbound_preview={@inbound_preview}
            tools_path={@tools_path}
          />
          <.sales_kits_card
            sales_click_count={@sales_click_count}
            sales_order_count={@sales_order_count}
            sales_revenue={@sales_revenue}
            sales_preview={@sales_preview}
            tools_path={@tools_path}
          />
        </div>
      </div>

      <.earn_tools
        goal_progress={@goal_progress}
        income_goal={@income_goal}
        opportunity_radar_count={@opportunity_radar_count}
        content_draft_count={@content_draft_count}
        commerce_passport={@commerce_passport}
        group_buy_count={@group_buy_count}
        sales_team_count={@sales_team_count}
        franchise_package_count={@franchise_package_count}
        available_franchise_count={@available_franchise_count}
        reservation_count={@reservation_count}
        tools_path={@tools_path}
      />

      <.listings_card
        listing_count={@listing_count}
        listing_preview={@listing_preview}
        tools_path={@tools_path}
      />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopySalesLink">
        export default {
          mounted() {
            this.el.addEventListener("click", () => navigator.clipboard.writeText(this.el.dataset.url))
          }
        }
      </script>
    </div>
    """
  end

  @doc "Every tool section on one page, reached from the hub's doors."
  def workbench(assigns) do
    ~H"""
    <div id="supply-network-tools" class="mx-auto max-w-6xl space-y-8 px-4 sm:px-6">
      <.link
        navigate={~p"/admin/settings/supply-network"}
        class="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-500 hover:text-slate-700"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Partners
      </.link>

      <GoalComponents.goal
        goal_progress={@goal_progress}
        hustle_listings={@hustle_listings}
        hustle_opportunities={@hustle_opportunities}
        hustle_plan={@hustle_plan}
        hustle_shares={@hustle_shares}
        income_goal={@income_goal}
        income_goal_form={@income_goal_form}
      />
      <CollaborationComponents.collaboration
        collaboration_owned_offers={@collaboration_owned_offers}
        commerce_passport={@commerce_passport}
        current_store={@current_store}
        franchise_form={@franchise_form}
        group_buy_form={@group_buy_form}
        hustle_listings={@hustle_listings}
        inventory_policy_form={@inventory_policy_form}
        inventory_reservation_forms={@inventory_reservation_forms}
        passport_appeal_forms={@passport_appeal_forms}
        sales_team_form={@sales_team_form}
        streams={@streams}
      />
      <OpportunityComponents.opportunities
        business_command_form={@business_command_form}
        pending_business_command={@pending_business_command}
        starter_business_form={@starter_business_form}
        streams={@streams}
        supplier_demand_alert_count={@supplier_demand_alert_count}
      />
      <CatalogComponents.catalog
        connection_count={@connection_count}
        content_draft_count={@content_draft_count}
        current_store={@current_store}
        form={@form}
        listing_count={@listing_count}
        offer_count={@offer_count}
        streams={@streams}
      />
      <ActivationComponents.activation
        delivery_form={@delivery_form}
        delivery_fulfillment_id={@delivery_fulfillment_id}
        first_money={@first_money}
        inbound_count={@inbound_count}
        sales_click_count={@sales_click_count}
        sales_order_count={@sales_order_count}
        sales_revenue={@sales_revenue}
        shipping_form={@shipping_form}
        shipping_fulfillment_id={@shipping_fulfillment_id}
        streams={@streams}
      />
    </div>
    """
  end

  # ── Tiles ────────────────────────────────────────────────────────

  attr :connections, :list, required: true
  attr :current_store, :any, required: true
  attr :connection_count, :integer, required: true
  attr :listing_count, :integer, required: true
  attr :low_stock_listing_count, :integer, required: true
  attr :sales_revenue, :integer, required: true
  attr :sales_order_count, :integer, required: true
  attr :sales_click_count, :integer, required: true
  attr :inbound_count, :integer, required: true

  defp hub_tiles(assigns) do
    assigns =
      assign(assigns, :incoming, incoming_count(assigns.connections, assigns.current_store))

    ~H"""
    <div id="partners-stats" class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div data-stat="partners">
        <.stat_card label="Partners" value={to_string(@connection_count)} tone={:primary}>
          <:icon><.icon name="hero-users" class="size-7" /></:icon>
          <:delta>
            <span class={[
              "text-xs font-semibold",
              if(@incoming > 0, do: "text-amber-700", else: "text-slate-500")
            ]}>
              {if @incoming > 0,
                do: "#{@incoming} invite#{plural(@incoming)} waiting for you",
                else: "Both stores must agree first"}
            </span>
          </:delta>
        </.stat_card>
      </div>
      <div data-stat="products">
        <.stat_card label="Partner products" value={to_string(@listing_count)} tone={:accent}>
          <:icon><.icon name="hero-tag" class="size-7" /></:icon>
          <:delta>
            <span class={[
              "text-xs font-semibold",
              if(@low_stock_listing_count > 0, do: "text-amber-700", else: "text-slate-500")
            ]}>
              {if @low_stock_listing_count > 0,
                do: "#{@low_stock_listing_count} running low",
                else: "Stock looks fine"}
            </span>
          </:delta>
        </.stat_card>
      </div>
      <div data-stat="sales">
        <.stat_card label="Partner sales" value={Currency.format_price(@sales_revenue)} tone={:info}>
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-slate-500">
              {@sales_order_count} orders · {@sales_click_count} clicks
            </span>
          </:delta>
        </.stat_card>
      </div>
      <div data-stat="fulfil">
        <.stat_card label="Orders to fulfil" value={to_string(@inbound_count)} tone={:warning}>
          <:icon><.icon name="hero-truck" class="size-7" /></:icon>
          <:delta>
            <span class="text-xs font-semibold text-amber-700">
              {if @inbound_count > 0,
                do: "Ship, then the customer gets a code",
                else: "Nothing waiting on you"}
            </span>
          </:delta>
        </.stat_card>
      </div>
    </div>
    """
  end

  # ── First Money strip ────────────────────────────────────────────

  attr :first_money, :map, required: true
  attr :tools_path, :string, required: true

  defp journey_strip(assigns) do
    steps =
      Enum.map(@journey, fn {key, label, hint} ->
        %{key: key, label: label, hint: hint, complete?: Map.get(assigns.first_money, key, false)}
      end)

    current = Enum.find(steps, &(!&1.complete?))
    done = Enum.count(steps, & &1.complete?)

    assigns = assign(assigns, steps: steps, current: current, done: done)

    ~H"""
    <.admin_card id="first-money-journey" padding={:none} class="px-6 py-[18px]">
      <div class="flex flex-col lg:flex-row lg:items-center gap-5">
        <ol class="flex flex-1 items-center gap-2 overflow-x-auto">
          <li
            :for={{step, index} <- Enum.with_index(@steps)}
            id={"first-money-step-#{step.key}"}
            data-complete={to_string(step.complete?)}
            class="flex items-center gap-2 flex-1 min-w-0"
          >
            <span
              :if={index > 0}
              class={[
                "h-0.5 w-6 lg:w-10 shrink-0 rounded",
                if(step.complete? or step == @current, do: "bg-emerald-600", else: "bg-slate-200")
              ]}
            >
            </span>
            <span class={[
              "flex size-10 shrink-0 items-center justify-center rounded-full",
              step.complete? && "bg-emerald-600 text-white",
              !step.complete? && step == @current &&
                "bg-white text-emerald-700 ring-2 ring-inset ring-emerald-600",
              !step.complete? && step != @current && "bg-slate-100 text-slate-400"
            ]}>
              <.icon :if={step.complete?} name="hero-check" class="size-5" />
              <.icon :if={!step.complete?} name={step_icon(step.key)} class="size-5" />
            </span>
            <span class="min-w-0">
              <span class="block text-[13.5px] font-bold text-slate-900">{step.label}</span>
              <span class={[
                "block text-[11px] truncate",
                if(step == @current, do: "text-emerald-700 font-semibold", else: "text-slate-400")
              ]}>
                {if step == @current, do: "#{step.hint} — next", else: step.hint}
              </span>
            </span>
          </li>
        </ol>
        <div class="flex items-center gap-3.5 shrink-0">
          <div class="text-right">
            <p class="text-[13px] font-bold text-slate-900">{@done} of {length(@steps)} done</p>
            <p class="text-[11px] text-slate-400">First money journey</p>
          </div>
          <.link
            :if={@current}
            navigate={@tools_path <> next_anchor(@current.key)}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] bg-emerald-600 hover:bg-emerald-700 text-white text-[13px] font-semibold transition-colors"
          >
            {next_action(@current.key)}
          </.link>
        </div>
      </div>
    </.admin_card>
    """
  end

  defp step_icon(:connected), do: "hero-users"
  defp step_icon(:listed), do: "hero-tag"
  defp step_icon(:shared), do: "hero-share"
  defp step_icon(:sold), do: "hero-shopping-cart"
  defp step_icon(_fulfilled), do: "hero-truck"

  defp next_anchor(:connected), do: "#supply-connection-form"
  defp next_anchor(:listed), do: "#earn-catalog"
  defp next_anchor(:shared), do: "#earned-listings"
  defp next_anchor(:sold), do: "#sales-shares"
  defp next_anchor(_fulfilled), do: "#supplier-inbox"

  defp next_action(:connected), do: "Invite a store"
  defp next_action(:listed), do: "Add a product"
  defp next_action(:shared), do: "Make a sales kit"
  defp next_action(:sold), do: "Share a link"
  defp next_action(_fulfilled), do: "Ship an order"

  # ── Partners ─────────────────────────────────────────────────────

  attr :streams, :map, required: true
  attr :current_store, :any, required: true
  attr :connection_count, :integer, required: true
  attr :connections, :list, required: true
  attr :partner_stats, :map, required: true
  attr :form, :any, required: true

  defp partners_card(assigns) do
    assigns =
      assign(assigns, :incoming, incoming_count(assigns.connections, assigns.current_store))

    ~H"""
    <.admin_card padding={:none} class="overflow-hidden">
      <div class="flex items-center gap-2.5 px-5 pt-[18px] pb-3.5">
        <h2 class="text-base font-bold text-slate-900">Your partners</h2>
        <span
          id="connection-count"
          class="rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-bold text-slate-600 tabular-nums"
        >
          {@connection_count}
        </span>
        <span
          :if={@incoming > 0}
          class="rounded-full bg-amber-100 px-2.5 py-0.5 text-[11px] font-bold text-amber-800"
        >
          {@incoming} invite{plural(@incoming)}
        </span>
        <span class="ml-auto text-xs text-slate-500 hidden sm:block">
          Both stores must agree first
        </span>
      </div>

      <div id="supply-connections" phx-update="stream" class="divide-y divide-slate-100">
        <div id="connections-empty" class="hidden only:block px-5 py-10 text-center">
          <.icon name="hero-users" class="mx-auto size-9 text-slate-300" />
          <p class="mt-3 text-sm font-semibold text-slate-700">No partners yet</p>
          <p class="mt-1 text-xs text-slate-500">Invite a store you trust, below.</p>
        </div>
        <.partner_row
          :for={{dom_id, connection} <- @streams.connections}
          id={dom_id}
          connection={connection}
          current_store={@current_store}
          stats={Map.get(@partner_stats, partner(connection, @current_store.id).id, %{})}
        />
      </div>

      <.form
        for={@form}
        id="supply-connection-form"
        phx-submit="request_connection"
        class="flex flex-col sm:flex-row sm:items-end gap-2.5 px-5 py-3.5 border-t border-slate-100 bg-slate-50"
      >
        <div class="flex-1 min-w-0">
          <.input
            field={@form[:partner_slug]}
            type="text"
            label="Store address"
            placeholder="e.g. kente-kingdom"
            required
          />
        </div>
        <div class="sm:w-56">
          <.input
            field={@form[:relationship]}
            type="select"
            label="What do you want to do?"
            options={[
              {"Sell their products", "resell"},
              {"Supply products to them", "supply"}
            ]}
          />
        </div>
        <button
          id="send-connection-invite"
          type="submit"
          class="inline-flex h-[42px] items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 text-sm font-semibold text-white transition hover:bg-emerald-700"
        >
          <.icon name="hero-paper-airplane" class="size-4" /> Send invite
        </button>
      </.form>
    </.admin_card>
    """
  end

  attr :id, :string, required: true
  attr :connection, :map, required: true
  attr :current_store, :any, required: true
  attr :stats, :map, required: true

  defp partner_row(assigns) do
    assigns =
      assign(assigns,
        partner: partner(assigns.connection, assigns.current_store.id),
        incoming?: incoming?(assigns.connection, assigns.current_store.id),
        supplying?: assigns.connection.wholesaler_store_id == assigns.current_store.id
      )

    ~H"""
    <article
      id={@id}
      data-products={Map.get(@stats, :products, 0)}
      class={[
        "flex flex-wrap sm:flex-nowrap items-center gap-3.5 px-5 py-3.5",
        @incoming? && "bg-amber-50/70 border-l-4 border-amber-400 pl-4"
      ]}
    >
      <.partner_avatar store={@partner} />
      <div class="min-w-0 flex-1">
        <h3 class="text-[14.5px] font-bold text-slate-900 truncate">{@partner.name}</h3>
        <p class={[
          "mt-0.5 flex items-center gap-1.5 text-xs font-medium",
          if(@incoming?, do: "text-amber-800", else: "text-slate-600")
        ]}>
          <.icon
            name={
              cond do
                @incoming? -> "hero-envelope"
                @supplying? -> "hero-arrow-left"
                true -> "hero-arrow-right"
              end
            }
            class="size-3.5"
          />
          {if @incoming?,
            do: "Wants to " <> incoming_verb(@supplying?),
            else: relationship_label(@connection, @current_store.id)}
        </p>
        <p :if={@connection.status_reason} class="text-[11px] text-slate-400 mt-0.5">
          {@connection.status_reason}
        </p>
      </div>

      <div :if={!@incoming? and !@supplying?} class="hidden md:flex items-center gap-5">
        <.mini_stat label="products" value={Map.get(@stats, :products, 0)} />
        <.mini_stat label="orders" value={Map.get(@stats, :orders, 0)} />
      </div>

      <span
        :if={!@incoming?}
        class={[
          "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-bold capitalize ring-1 ring-inset",
          status_classes(@connection.status)
        ]}
      >
        <span
          :if={@connection.status == :active}
          class="size-1.5 rounded-full bg-emerald-500"
        >
        </span>
        {if @connection.status == :pending, do: "Waiting", else: humanize(@connection.status)}
      </span>

      <div class="flex items-center gap-2 shrink-0">
        <%= if @incoming? do %>
          <button
            id={"reject-connection-#{@connection.id}"}
            phx-click="reject_connection"
            phx-value-id={@connection.id}
            class="rounded-[10px] border border-slate-200 bg-white px-3.5 py-2 text-[13px] font-semibold text-slate-700 transition hover:bg-slate-50"
          >
            Decline
          </button>
          <button
            id={"approve-connection-#{@connection.id}"}
            phx-click="approve_connection"
            phx-value-id={@connection.id}
            class="inline-flex items-center gap-1.5 rounded-[10px] bg-emerald-600 px-3.5 py-2 text-[13px] font-semibold text-white transition hover:bg-emerald-700"
          >
            <.icon name="hero-check" class="size-4" /> Accept
          </button>
        <% end %>
        <button
          :if={@connection.status == :active}
          id={"suspend-connection-#{@connection.id}"}
          phx-click="suspend_connection"
          phx-value-id={@connection.id}
          class="rounded-[10px] px-3 py-2 text-xs font-semibold text-amber-700 transition hover:bg-amber-50"
        >
          Pause
        </button>
        <button
          :if={@connection.status == :suspended}
          id={"reactivate-connection-#{@connection.id}"}
          phx-click="reactivate_connection"
          phx-value-id={@connection.id}
          class="rounded-[10px] bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
        >
          Reactivate
        </button>
        <button
          :if={@connection.status in [:pending, :active, :suspended] and !@incoming?}
          id={"terminate-connection-#{@connection.id}"}
          phx-click="terminate_connection"
          phx-value-id={@connection.id}
          class="rounded-[10px] px-3 py-2 text-xs font-semibold text-rose-600 transition hover:bg-rose-50"
        >
          End
        </button>
      </div>
    </article>
    """
  end

  defp incoming_verb(true), do: "sell your products"
  defp incoming_verb(false), do: "supply you"

  attr :store, :map, required: true

  defp partner_avatar(assigns) do
    ~H"""
    <img
      :if={@store.logo_url}
      src={@store.logo_url}
      alt=""
      class="size-11 shrink-0 rounded-xl object-cover"
    />
    <span
      :if={!@store.logo_url}
      class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-lg font-extrabold text-emerald-700"
    >
      {@store.name |> String.first() |> String.upcase()}
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp mini_stat(assigns) do
    ~H"""
    <span class="flex flex-col items-center min-w-14">
      <span class="text-base font-extrabold text-slate-900 leading-none tabular-nums">{@value}</span>
      <span class="mt-0.5 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
        {@label}
      </span>
    </span>
    """
  end

  # ── Orders to fulfil ─────────────────────────────────────────────

  attr :inbound_count, :integer, required: true
  attr :inbound_preview, :list, required: true
  attr :tools_path, :string, required: true

  defp inbound_card(assigns) do
    ~H"""
    <.admin_card id="hub-inbound" padding={:none} class="overflow-hidden">
      <div class="flex items-center gap-2.5 px-5 pt-[18px] pb-3.5">
        <h2 class="text-base font-bold text-slate-900">Orders to fulfil</h2>
        <span
          id="hub-inbound-count"
          class="rounded-full bg-amber-100 px-2.5 py-0.5 text-[11px] font-bold text-amber-800 tabular-nums"
        >
          {@inbound_count}
        </span>
        <.link
          navigate={@tools_path <> "#supplier-inbox"}
          class="ml-auto text-xs font-semibold text-emerald-700 hover:text-emerald-800"
        >
          All orders
        </.link>
      </div>
      <p
        :if={@inbound_count > 0}
        class="mx-5 mb-1 flex items-center gap-2.5 rounded-[10px] border-l-4 border-amber-400 bg-amber-50 px-3 py-2.5 text-xs font-semibold text-amber-800"
      >
        <.icon name="hero-clock" class="size-4 shrink-0" /> Pack, ship, then the customer gets a code
      </p>
      <p :if={@inbound_count == 0} class="px-5 pb-5 text-sm text-slate-400">
        No partner orders need attention.
      </p>
      <div class="divide-y divide-slate-100">
        <div
          :for={fulfillment <- @inbound_preview}
          id={"hub-inbound-#{fulfillment.id}"}
          class="flex items-start gap-3.5 px-5 py-3.5"
        >
          <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-500">
            <.icon name="hero-cube" class="size-5" />
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="text-sm font-bold text-slate-900">
                Order {fulfillment.order.order_number}
              </span>
              <span class={[
                "rounded-full px-2.5 py-0.5 text-[11px] font-bold capitalize",
                fulfillment_status_classes(fulfillment.status)
              ]}>
                {fulfillment.status}
              </span>
            </div>
            <p class="mt-0.5 text-xs text-slate-500">
              Sold by {fulfillment.supplier.name} · Deliver to {customer_city(fulfillment.order)}
            </p>
            <p class="mt-0.5 text-xs text-slate-700 truncate">
              {Enum.map_join(fulfillment.line_items, " · ", &"#{&1.product_title} × #{&1.quantity}")}
            </p>
            <.link
              navigate={@tools_path <> "#supplier-inbox"}
              class={[
                "mt-2.5 inline-flex items-center gap-1.5 rounded-[10px] px-3.5 py-2 text-[13px] font-semibold transition",
                if(fulfillment.status in [:pending, :notified],
                  do: "bg-emerald-600 text-white hover:bg-emerald-700",
                  else: "border border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
                )
              ]}
            >
              <.icon name="hero-truck" class="size-4" />
              {if fulfillment.status in [:pending, :notified],
                do: "Mark shipped",
                else: "Delivery code"}
            </.link>
          </div>
        </div>
      </div>
    </.admin_card>
    """
  end

  # ── Sales kits ───────────────────────────────────────────────────

  attr :sales_click_count, :integer, required: true
  attr :sales_order_count, :integer, required: true
  attr :sales_revenue, :integer, required: true
  attr :sales_preview, :list, required: true
  attr :tools_path, :string, required: true

  defp sales_kits_card(assigns) do
    ~H"""
    <.admin_card id="hub-sales-kits" padding={:none} class="overflow-hidden">
      <div class="flex items-center gap-2.5 px-5 pt-[18px] pb-3">
        <h2 class="text-base font-bold text-slate-900">Sales kits</h2>
        <.link
          navigate={@tools_path <> "#sales-shares"}
          class="ml-auto text-xs font-semibold text-emerald-700 hover:text-emerald-800"
        >
          All kits
        </.link>
      </div>
      <div class="grid grid-cols-3 gap-2.5 px-5 pb-3.5">
        <div class="rounded-xl bg-slate-50 px-3 py-3 text-center">
          <p class="text-xl font-extrabold text-slate-900 tabular-nums">{@sales_click_count}</p>
          <p class="text-[11px] font-semibold text-slate-500">Clicks</p>
        </div>
        <div class="rounded-xl bg-slate-50 px-3 py-3 text-center">
          <p class="text-xl font-extrabold text-slate-900 tabular-nums">{@sales_order_count}</p>
          <p class="text-[11px] font-semibold text-slate-500">Orders</p>
        </div>
        <div class="rounded-xl bg-emerald-50 px-3 py-3 text-center">
          <p class="text-xl font-extrabold text-emerald-700 tabular-nums">
            {Currency.format_price(@sales_revenue)}
          </p>
          <p class="text-[11px] font-semibold text-emerald-600">Sales</p>
        </div>
      </div>
      <p :if={@sales_preview == []} class="px-5 pb-5 text-sm text-slate-400">
        Add a partner product, then make a sales kit to share.
      </p>
      <div class="divide-y divide-slate-100">
        <div
          :for={share <- @sales_preview}
          id={"hub-share-#{share.id}"}
          class="flex items-center gap-3.5 px-5 py-3.5"
        >
          <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
            <.icon name={channel_icon(share.channel)} class="size-5" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-bold text-slate-900 truncate">{share.product.title}</p>
            <p class="text-xs text-slate-500">
              {channel_label(share.channel)} · {share.click_count} clicks · {share.order_count} orders
            </p>
          </div>
          <.share_button share={share} />
        </div>
      </div>
    </.admin_card>
    """
  end

  attr :share, :map, required: true

  defp share_button(%{share: %{channel: :copy_link}} = assigns) do
    ~H"""
    <button
      id={"hub-copy-sales-link-#{@share.id}"}
      type="button"
      phx-hook=".CopySalesLink"
      phx-click="record_sales_share"
      phx-value-id={@share.id}
      data-url={sales_share_url(@share)}
      class="rounded-[10px] border border-slate-200 bg-white px-3.5 py-2 text-[13px] font-semibold text-slate-700 transition hover:bg-slate-50"
    >
      Copy link
    </button>
    """
  end

  defp share_button(assigns) do
    ~H"""
    <a
      id={"hub-share-#{@share.channel}-#{@share.id}"}
      href={
        if @share.channel == :whatsapp,
          do: whatsapp_share_url(@share),
          else: facebook_share_url(@share)
      }
      target="_blank"
      rel="noopener"
      phx-click="record_sales_share"
      phx-value-id={@share.id}
      class="rounded-[10px] bg-emerald-600 px-3.5 py-2 text-[13px] font-semibold text-white transition hover:bg-emerald-700"
    >
      Share
    </a>
    """
  end

  # ── Earn tools ───────────────────────────────────────────────────

  attr :goal_progress, :any, required: true
  attr :income_goal, :any, required: true
  attr :opportunity_radar_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :commerce_passport, :any, required: true
  attr :group_buy_count, :integer, required: true
  attr :sales_team_count, :integer, required: true
  attr :franchise_package_count, :integer, required: true
  attr :available_franchise_count, :integer, required: true
  attr :reservation_count, :integer, required: true
  attr :tools_path, :string, required: true

  defp earn_tools(assigns) do
    ~H"""
    <div id="earn-tools" class="space-y-3">
      <div class="flex items-baseline gap-2.5">
        <h2 class="text-base font-bold text-slate-900">Earn tools</h2>
        <span class="text-xs text-slate-500">Each opens its own section</span>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3.5">
        <.door
          key="income-plan"
          href={@tools_path <> "#hustle-autopilot"}
          icon="hero-flag"
          tint="bg-violet-50 text-violet-700"
          title="Income plan"
          line={goal_line(@income_goal, @goal_progress)}
          progress={goal_percent(@goal_progress)}
        />
        <.door
          key="opportunity-radar"
          href={@tools_path <> "#opportunity-radar"}
          icon="hero-signal"
          tint="bg-sky-50 text-sky-700"
          title="Opportunity radar"
          line={count_line(@opportunity_radar_count, "product", "people want")}
        />
        <.door
          key="content-studio"
          href={@tools_path <> "#earn-content-studio"}
          icon="hero-sparkles"
          tint="bg-pink-50 text-pink-700"
          title="Content studio"
          line={count_line(@content_draft_count, "draft", "to approve")}
          attention={@content_draft_count > 0}
        />
        <.door
          key="commerce-passport"
          href={@tools_path <> "#commerce-passport"}
          icon="hero-shield-check"
          tint="bg-emerald-50 text-emerald-700"
          title="Commerce passport"
          line={passport_line(@commerce_passport)}
        />
        <.door
          key="group-buys"
          href={@tools_path <> "#group-buy-form"}
          icon="hero-user-group"
          tint="bg-fuchsia-50 text-fuchsia-700"
          title="Group buys"
          line={count_line(@group_buy_count, "campaign", "open")}
        />
        <.door
          key="sales-teams"
          href={@tools_path <> "#sales-team-form"}
          icon="hero-user-plus"
          tint="bg-blue-50 text-blue-700"
          title="Sales teams"
          line={count_line(@sales_team_count, "team", "")}
        />
        <.door
          key="micro-franchise"
          href={@tools_path <> "#franchise-package-form"}
          icon="hero-cube"
          tint="bg-orange-50 text-orange-700"
          title="Micro-franchise"
          line={franchise_line(@franchise_package_count, @available_franchise_count)}
          attention={@available_franchise_count > 0}
        />
        <.door
          key="stock-holds"
          href={@tools_path <> "#inventory-eligibility"}
          icon="hero-lock-closed"
          tint="bg-amber-50 text-amber-700"
          title="Stock holds"
          line={count_line(@reservation_count, "hold", "")}
        />
      </div>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :tint, :string, required: true
  attr :title, :string, required: true
  attr :line, :string, required: true
  attr :progress, :integer, default: nil
  attr :attention, :boolean, default: false

  defp door(assigns) do
    ~H"""
    <.link
      id={"earn-tool-#{@key}"}
      navigate={@href}
      class="flex items-center gap-3.5 rounded-2xl border border-slate-200 bg-white px-[18px] py-4 shadow-sm transition hover:border-emerald-200 hover:shadow-md"
    >
      <span class={["flex size-11 shrink-0 items-center justify-center rounded-xl", @tint]}>
        <.icon name={@icon} class="size-[22px]" />
      </span>
      <span class="min-w-0 flex-1">
        <span class="block text-sm font-bold text-slate-900">{@title}</span>
        <span class={[
          "block text-xs mt-0.5",
          if(@attention, do: "text-amber-700 font-semibold", else: "text-slate-500")
        ]}>
          {@line}
        </span>
        <span :if={@progress} class="mt-2 block h-1.5 w-full rounded bg-slate-200 overflow-hidden">
          <span class="block h-full rounded bg-violet-600" style={"width: #{@progress}%"}></span>
        </span>
      </span>
      <.icon name="hero-chevron-right" class="size-4 text-slate-300" />
    </.link>
    """
  end

  defp goal_line(nil, _progress), do: "Set a target"

  defp goal_line(goal, progress) do
    "#{Currency.format_price(goal.target_amount)} target · #{goal_percent(progress) || 0}% there"
  end

  defp goal_percent(%{percent: percent}) when is_number(percent), do: round(percent)
  defp goal_percent(_progress), do: nil

  defp passport_line(nil), do: "Build your track record"
  defp passport_line(passport), do: "#{humanize(passport.tier)} · #{passport.score} points"

  defp franchise_line(owned, available) do
    parts =
      [{owned, "package"}, {available, "to join"}]
      |> Enum.reject(fn {count, _word} -> count == 0 end)
      |> Enum.map(fn
        {count, "package"} -> "#{count} package#{plural(count)}"
        {count, "to join"} -> "#{count} to join"
      end)

    if parts == [], do: "Package what you sell", else: Enum.join(parts, " · ")
  end

  defp count_line(0, word, _suffix), do: "No #{word}s yet"

  defp count_line(count, word, suffix),
    do: String.trim("#{count} #{word}#{plural(count)} #{suffix}")

  defp humanize(value) when is_atom(value), do: value |> to_string() |> String.capitalize()
  defp humanize(value), do: to_string(value)

  # ── Added from partners ──────────────────────────────────────────

  attr :listing_count, :integer, required: true
  attr :listing_preview, :list, required: true
  attr :tools_path, :string, required: true

  defp listings_card(assigns) do
    ~H"""
    <.admin_card id="hub-listings" padding={:none} class="overflow-hidden">
      <div class="flex items-center gap-2.5 px-5 pt-[18px] pb-3.5">
        <h2 class="text-base font-bold text-slate-900">Added from partners</h2>
        <span
          id="listing-count"
          class="rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-bold text-slate-600 tabular-nums"
        >
          {@listing_count}
        </span>
        <span class="ml-auto text-xs text-slate-500 hidden sm:block">
          They ship through their supplier
        </span>
      </div>
      <p :if={@listing_preview == []} class="px-5 pb-5 text-sm text-slate-400">
        Nothing added yet.
        <.link navigate={~p"/admin/supply/catalog"} class="font-semibold text-emerald-700">
          Browse suppliers
        </.link>
      </p>
      <div class="divide-y divide-slate-100">
        <div
          :for={listing <- @listing_preview}
          id={"hub-listing-#{listing.id}"}
          class="flex flex-wrap sm:flex-nowrap items-center gap-3.5 px-5 py-3.5"
        >
          <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
            <.icon name="hero-shopping-bag" class="size-5" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-bold text-slate-900 truncate">{listing.reseller_product.title}</p>
            <p class="mt-0.5 text-xs capitalize text-slate-500">
              {listing.status} · synced from partner
            </p>
          </div>
          <div id={"hub-listing-stock-#{listing.id}"}>
            <.supplier_stock_badge status={listing_stock_status(listing)} />
          </div>
          <button
            id={"hub-create-sales-kit-#{listing.id}"}
            phx-click="create_sales_kit"
            phx-value-id={listing.id}
            class="rounded-[10px] border border-slate-200 bg-white px-3.5 py-2 text-[13px] font-semibold text-slate-700 transition hover:bg-slate-50"
          >
            Sales kit
          </button>
          <.link
            navigate={~p"/admin/products/#{listing.reseller_product_id}/edit"}
            class="rounded-[10px] p-2 text-slate-400 transition hover:bg-slate-50 hover:text-slate-700"
            aria-label={"Edit #{listing.reseller_product.title}"}
          >
            <.icon name="hero-pencil-square" class="size-4" />
          </.link>
        </div>
      </div>
      <.link
        :if={@listing_count > length(@listing_preview)}
        navigate={@tools_path <> "#earned-listings"}
        class="block border-t border-slate-100 px-5 py-3 text-center text-xs font-semibold text-emerald-700 hover:text-emerald-800"
      >
        Show all {@listing_count}
      </.link>
    </.admin_card>
    """
  end

  # ── Shared helpers ───────────────────────────────────────────────

  defp incoming_count(_connections, nil), do: 0
  defp incoming_count(connections, store), do: Enum.count(connections, &incoming?(&1, store.id))

  defp plural(1), do: ""
  defp plural(_count), do: "s"
end
