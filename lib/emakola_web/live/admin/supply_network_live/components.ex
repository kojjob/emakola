defmodule EmakolaWeb.Admin.SupplyNetworkLive.Components do
  @moduledoc "Function components for the supply-network page."

  use EmakolaWeb, :html

  alias EmakolaWeb.Admin.SupplyNetworkLive.{
    ActivationComponents,
    CatalogComponents,
    CollaborationComponents,
    GoalComponents,
    OpportunityComponents
  }

  def page(assigns) do
    ~H"""
    <div id="supply-network-page" class="mx-auto max-w-6xl space-y-8 px-4 sm:px-6">
      <header class="overflow-hidden rounded-3xl bg-slate-950 px-6 py-8 text-white shadow-xl sm:px-10">
        <div class="max-w-2xl">
          <span class="inline-flex items-center gap-2 rounded-full bg-emerald-400/10 px-3 py-1 text-xs font-semibold text-emerald-300 ring-1 ring-emerald-400/20">
            <.icon name="hero-sparkles" class="size-4" /> Makola Earn
          </span>
          <h1 class="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">
            Earn without buying stock
          </h1>
          <p class="mt-3 max-w-xl text-sm leading-6 text-slate-300 sm:text-base">
            Connect with another verified store. They hold the products, you bring the customers,
            and Makola keeps each relationship visible and controlled by both parties.
          </p>
        </div>
      </header>

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
end
