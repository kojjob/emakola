defmodule EmakolaWeb.Admin.SupplyNetworkLive.Inputs do
  @moduledoc "Form defaults and input translation for the supply-network page."

  import Phoenix.Component, only: [to_form: 2]

  @spec default_assigns() :: map()
  def default_assigns do
    %{
      page_title: "Partners",
      active_nav: :supply_network,
      connection_count: 0,
      offer_count: 0,
      listing_count: 0,
      sales_share_count: 0,
      sales_click_count: 0,
      sales_order_count: 0,
      sales_revenue: 0,
      income_goal: nil,
      hustle_plan: nil,
      hustle_opportunities: [],
      hustle_listings: [],
      hustle_shares: [],
      goal_progress: nil,
      content_draft_count: 0,
      pending_business_command: nil,
      business_command_form: business_command_form(),
      starter_business_form: starter_business_form(),
      opportunity_radar_count: 0,
      supplier_demand_alert_count: 0,
      group_buy_count: 0,
      sales_team_count: 0,
      franchise_package_count: 0,
      available_franchise_count: 0,
      commerce_passport: nil,
      passport_appeal_forms: %{},
      inventory_policy_form: inventory_policy_form(),
      inventory_reservation_forms: %{},
      group_buy_form: group_buy_form(),
      sales_team_form: sales_team_form(),
      franchise_form: franchise_form(),
      income_goal_form: income_goal_form(),
      first_money: %{},
      active_connection?: false,
      inbound_count: 0,
      shipping_fulfillment_id: nil,
      shipping_form: shipment_form(),
      delivery_fulfillment_id: nil,
      delivery_form: delivery_form(),
      form: connection_form()
    }
  end

  def connection_attrs(current_store_id, partner_store_id, "supply") do
    %{
      wholesaler_store_id: current_store_id,
      reseller_store_id: partner_store_id,
      requested_by_store_id: current_store_id
    }
  end

  def connection_attrs(current_store_id, partner_store_id, _resell) do
    %{
      wholesaler_store_id: partner_store_id,
      reseller_store_id: current_store_id,
      requested_by_store_id: current_store_id
    }
  end

  def connection_form do
    to_form(%{"partner_slug" => "", "relationship" => "resell"}, as: :connection)
  end

  def inventory_policy_form do
    to_form(
      %{
        "offer_variant_id" => "",
        "minimum_tier" => "reliable",
        "max_quantity_per_reseller" => "5",
        "reservation_hours" => "72"
      },
      as: :inventory_policy
    )
  end

  def income_goal_form do
    to_form(
      %{
        "target_amount" => "",
        "timeframe_days" => "30",
        "daily_minutes" => "45",
        "channels" => ["whatsapp"]
      },
      as: :income_goal
    )
  end

  def business_command_form do
    to_form(%{"instruction" => ""}, as: :business_command)
  end

  def starter_business_form do
    to_form(%{"niche" => "", "count" => "3"}, as: :starter_business)
  end

  def group_buy_form(now \\ DateTime.utc_now()) do
    deadline = DateTime.add(now, 7, :day)
    refund = DateTime.add(deadline, 2, :day)

    to_form(
      %{
        "listing_variant_id" => "",
        "title" => "",
        "threshold_quantity" => "10",
        "unit_price" => "",
        "deadline" => Calendar.strftime(deadline, "%Y-%m-%dT%H:%M"),
        "refund_deadline" => Calendar.strftime(refund, "%Y-%m-%dT%H:%M")
      },
      as: :group_buy
    )
  end

  def sales_team_form do
    to_form(
      %{
        "name" => "",
        "collaborator_email" => "",
        "collaborator_role" => "seller",
        "owner_percent" => "60",
        "collaborator_percent" => "40"
      },
      as: :sales_team
    )
  end

  def franchise_form do
    to_form(
      %{
        "name" => "",
        "offer_id" => "",
        "training" => "",
        "brand_rules" => "",
        "channel_permissions" => ["storefront", "whatsapp"],
        "territory" => "",
        "commission_bps" => "1000"
      },
      as: :franchise
    )
  end

  def shipment_form, do: to_form(%{"tracking_number" => ""}, as: :shipment)
  def delivery_form, do: to_form(%{"code" => ""}, as: :delivery)

  def inventory_reservation_form(policy_id) do
    to_form(%{"policy_id" => policy_id, "quantity" => "1"},
      as: :inventory_reservation,
      id: "inventory-reservation-#{policy_id}"
    )
  end

  def passport_appeal_form(signal_id) do
    to_form(%{"signal_id" => signal_id, "reason" => ""},
      as: :appeal,
      id: "appeal-#{signal_id}"
    )
  end

  def find_listing_mapping(listings, mapping_id) do
    listings
    |> Enum.flat_map(& &1.listing_variants)
    |> Enum.find(&(&1.id == mapping_id))
  end

  def group_buy_attrs(params, mapping) do
    %{
      listing_id: mapping.listing_id,
      listing_variant_id: mapping.id,
      title: params["title"],
      threshold_quantity: params["threshold_quantity"],
      unit_price: cedis_to_pesewas(params["unit_price"]),
      deadline: local_datetime(params["deadline"]),
      refund_deadline: local_datetime(params["refund_deadline"])
    }
  end

  def franchise_attrs(params) do
    %{
      name: params["name"],
      offer_ids: [params["offer_id"]],
      training: %{"summary" => params["training"]},
      brand_rules: %{"rules" => params["brand_rules"]},
      channel_permissions: params["channel_permissions"] || ["storefront"],
      territory: params["territory"],
      commission_bps: params["commission_bps"]
    }
  end

  def income_goal_attrs(params) do
    Map.update(params, "target_amount", "", &cedis_to_pesewas/1)
  end

  def percent_bps(value) do
    case Decimal.parse(String.trim(value || "")) do
      {percent, ""} ->
        bps = percent |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()
        if bps in 1..10_000, do: {:ok, bps}, else: {:error, :invalid_percent}

      _ ->
        {:error, :invalid_percent}
    end
  end

  def cedis_to_pesewas(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {amount, ""} ->
        amount
        |> Decimal.mult(100)
        |> Decimal.round(0)
        |> Decimal.to_integer()
        |> Integer.to_string()

      _ ->
        value
    end
  end

  def cedis_to_pesewas(value), do: value

  defp local_datetime(value), do: value <> ":00Z"
end
