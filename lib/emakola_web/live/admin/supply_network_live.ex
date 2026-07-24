defmodule EmakolaWeb.Admin.SupplyNetworkLive do
  @moduledoc "Merchant UI for SP2 wholesaler/reseller supply connections."
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Suppliers.{
    BusinessCommand,
    CommercePassports,
    ContentStudio,
    HustlePlanner,
    GoalProgress,
    Franchises,
    GroupBuys,
    InboundFulfillment,
    IncomeGoals,
    InventoryReservations,
    ListingImporter,
    Network,
    OpportunityRadar,
    OpportunitySignals,
    Offers,
    SalesSharing,
    SalesTeams,
    StarterBusiness
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
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
       shipping_form: to_form(%{"tracking_number" => ""}, as: :shipment),
       delivery_fulfillment_id: nil,
       delivery_form: to_form(%{"code" => ""}, as: :delivery),
       form: connection_form()
     )
     |> load_connections()
     |> load_earn_catalog()
     |> load_inbound_fulfillments()
     |> load_sales_journey()
     |> load_income_goal()
     |> load_content_drafts()
     |> load_opportunity_radar()
     |> load_collaborative_commerce()
     |> load_commerce_passport()
     |> load_inventory_eligibility()}
  end

  @impl true
  def handle_event("request_connection", %{"connection" => params}, socket) do
    store = socket.assigns.current_store
    actor = socket.assigns.current_merchant
    slug = params |> Map.get("partner_slug", "") |> String.trim()

    case Emakola.Stores.get_store_by_slug(slug, authorize?: false) do
      {:ok, partner} ->
        attrs = connection_attrs(store.id, partner.id, params["relationship"])

        case Network.request(actor, attrs) do
          {:ok, _connection} ->
            {:noreply,
             socket
             |> assign(:form, connection_form())
             |> load_connections()
             |> put_flash(:info, "Invitation sent to #{partner.name}.")}

          {:error, :connection_exists} ->
            {:noreply, put_flash(socket, :error, "A connection with this store already exists.")}

          {:error, :stores_must_differ} ->
            {:noreply, put_flash(socket, :error, "Choose another store, not your own.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "The invitation could not be sent.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No store was found with that Makola address.")}
    end
  end

  def handle_event("approve_connection", %{"id" => id}, socket),
    do: update_connection(socket, id, &Network.approve/2, "Connection approved.")

  def handle_event("reject_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.reject(&1, &2, "Declined by partner"),
      "Invitation declined."
    )
  end

  def handle_event("suspend_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.suspend(&1, &2, "Paused by merchant"),
      "Connection paused."
    )
  end

  def handle_event("reactivate_connection", %{"id" => id}, socket),
    do: update_connection(socket, id, &Network.reactivate/2, "Connection reactivated.")

  def handle_event("terminate_connection", %{"id" => id}, socket) do
    update_connection(
      socket,
      id,
      &Network.terminate(&1, &2, "Ended by merchant"),
      "Connection ended."
    )
  end

  def handle_event("import_offer", %{"id" => offer_id}, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    with {:ok, offers} <- Offers.list_available(actor, store.id),
         %{} = offer <- Enum.find(offers, &(&1.id == offer_id)),
         {:ok, _listing} <- ListingImporter.import(actor, store.id, offer) do
      {:noreply,
       socket
       |> load_earn_catalog()
       |> load_sales_journey()
       |> load_income_goal()
       |> load_collaborative_commerce()
       |> put_flash(:info, "Product added to your store. Its images are being prepared.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "This offer is no longer available.")}

      {:error, :listing_exists} ->
        {:noreply,
         socket
         |> load_earn_catalog()
         |> load_sales_journey()
         |> load_income_goal()
         |> load_collaborative_commerce()
         |> put_flash(:info, "Already in your store.")}

      _ ->
        {:noreply, put_flash(socket, :error, "This product could not be added right now.")}
    end
  end

  def handle_event("create_sales_kit", %{"id" => listing_id}, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    with {:ok, listings} <- ListingImporter.list(actor, store.id),
         %{} = listing <- Enum.find(listings, &(&1.id == listing_id)),
         {:ok, _shares} <- SalesSharing.create_kit(actor, listing) do
      {:noreply,
       socket
       |> load_sales_journey()
       |> load_income_goal()
       |> put_flash(:info, "Sales kit ready. Share it where your customers already chat.")}
    else
      _ -> {:noreply, put_flash(socket, :error, "The sales kit could not be created.")}
    end
  end

  def handle_event("create_content_draft", %{"id" => listing_id} = params, socket) do
    case ContentStudio.create_draft(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           listing_id,
           locale: Map.get(params, "locale", "en-GH")
         ) do
      {:ok, _draft} ->
        {:noreply,
         socket
         |> load_content_drafts()
         |> put_flash(:info, "Content draft ready for your review.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The content draft could not be created.")}
    end
  end

  def handle_event("approve_content_draft", %{"id" => id}, socket) do
    case ContentStudio.approve(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id
         ) do
      {:ok, _draft} ->
        {:noreply, socket |> load_content_drafts() |> put_flash(:info, "Content approved.")}

      {:error, :source_facts_changed} ->
        {:noreply,
         socket
         |> load_content_drafts()
         |> put_flash(:error, "Supplier facts changed. Generate a fresh draft before sharing.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The content could not be approved.")}
    end
  end

  def handle_event("reject_content_draft", %{"id" => id}, socket) do
    case ContentStudio.reject(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id
         ) do
      {:ok, _draft} ->
        {:noreply, socket |> load_content_drafts() |> put_flash(:info, "Draft rejected.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The draft could not be rejected.")}
    end
  end

  def handle_event(
        "preview_business_command",
        %{"business_command" => %{"instruction" => instruction}},
        socket
      ) do
    case BusinessCommand.parse(instruction) do
      {:ok, command} ->
        {:noreply, assign(socket, :pending_business_command, command)}

      {:error, :empty} ->
        {:noreply, put_flash(socket, :error, "Say or type an instruction first.")}

      {:error, :unsupported} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Try: “Add three products”, “Create a Sales Kit”, or “Make a content draft”."
         )}
    end
  end

  def handle_event("cancel_business_command", _params, socket) do
    {:noreply, assign(socket, :pending_business_command, nil)}
  end

  def handle_event("confirm_business_command", _params, socket) do
    case execute_business_command(socket, socket.assigns.pending_business_command) do
      {:ok, message} ->
        {:noreply,
         socket
         |> assign(
           pending_business_command: nil,
           business_command_form: business_command_form()
         )
         |> load_earn_catalog()
         |> load_sales_journey()
         |> load_income_goal()
         |> load_content_drafts()
         |> load_collaborative_commerce()
         |> put_flash(:info, message)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("build_starter_business", %{"starter_business" => params}, socket) do
    case StarterBusiness.build(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           params
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:starter_business_form, starter_business_form())
         |> load_earn_catalog()
         |> load_sales_journey()
         |> load_income_goal()
         |> load_content_drafts()
         |> load_collaborative_commerce()
         |> put_flash(
           :info,
           "Starter business ready: #{result.imported} products, tracked links, and reviewable content drafts."
         )}

      {:error, :no_matching_offers} ->
        {:noreply,
         put_flash(socket, :error, "Connect with a supplier that has eligible products first.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The starter business could not be created.")}
    end
  end

  def handle_event("refresh_opportunity_radar", _params, socket) do
    {:noreply, load_opportunity_radar(socket)}
  end

  def handle_event("create_group_buy", %{"group_buy" => params}, socket) do
    with %{} = mapping <-
           find_listing_mapping(socket.assigns.hustle_listings, params["listing_variant_id"]),
         attrs <- group_buy_attrs(params, mapping),
         {:ok, campaign} <-
           GroupBuys.create(
             socket.assigns.current_merchant,
             socket.assigns.current_store.id,
             attrs
           ),
         {:ok, _opened} <-
           GroupBuys.open(
             socket.assigns.current_merchant,
             socket.assigns.current_store.id,
             campaign.id
           ) do
      {:noreply,
       socket
       |> assign(:group_buy_form, group_buy_form())
       |> load_collaborative_commerce()
       |> put_flash(:info, "Group buy opened with a locked price and refund deadline.")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Choose an imported product variant.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, group_buy_error(reason))}
    end
  end

  def handle_event("create_sales_team", %{"sales_team" => params}, socket) do
    with {:ok, collaborator} <- merchant_by_email(params["collaborator_email"]),
         {:ok, owner_bps} <- percent_bps(params["owner_percent"]),
         {:ok, collaborator_bps} <- percent_bps(params["collaborator_percent"]),
         {:ok, _team} <-
           SalesTeams.create(
             socket.assigns.current_merchant,
             socket.assigns.current_store.id,
             params["name"],
             [
               %{
                 merchant_id: socket.assigns.current_merchant.id,
                 role: :owner,
                 split_bps: owner_bps
               },
               %{
                 merchant_id: collaborator.id,
                 role: params["collaborator_role"],
                 split_bps: collaborator_bps
               }
             ]
           ) do
      {:noreply,
       socket
       |> assign(:sales_team_form, sales_team_form())
       |> load_collaborative_commerce()
       |> put_flash(
         :info,
         "Team invitation created. Earnings stay inactive until the collaborator consents."
       )}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, sales_team_error(reason))}
    end
  end

  def handle_event("accept_sales_team", %{"id" => member_id}, socket) do
    case SalesTeams.accept(socket.assigns.current_merchant, member_id) do
      {:ok, _member} ->
        {:noreply,
         socket
         |> load_collaborative_commerce()
         |> put_flash(:info, "You accepted the declared role and split.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The invitation could not be accepted.")}
    end
  end

  def handle_event("create_franchise_package", %{"franchise" => params}, socket) do
    attrs = %{
      name: params["name"],
      offer_ids: [params["offer_id"]],
      training: %{"summary" => params["training"]},
      brand_rules: %{"rules" => params["brand_rules"]},
      channel_permissions: params["channel_permissions"] || ["storefront"],
      territory: params["territory"],
      commission_bps: params["commission_bps"]
    }

    with {:ok, package} <-
           Franchises.create(
             socket.assigns.current_merchant,
             socket.assigns.current_store.id,
             attrs
           ),
         {:ok, _published} <-
           Franchises.publish(
             socket.assigns.current_merchant,
             socket.assigns.current_store.id,
             package.id
           ) do
      {:noreply,
       socket
       |> assign(:franchise_form, franchise_form())
       |> load_collaborative_commerce()
       |> put_flash(:info, "Micro-franchise package published to connected resellers.")}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, franchise_error(reason))}
    end
  end

  def handle_event("apply_franchise", %{"id" => package_id}, socket) do
    case Franchises.apply(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           package_id,
           true
         ) do
      {:ok, _enrollment} ->
        {:noreply,
         socket
         |> load_collaborative_commerce()
         |> put_flash(:info, "Application sent with package terms accepted.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The package application could not be sent.")}
    end
  end

  def handle_event("approve_franchise", %{"id" => enrollment_id}, socket) do
    case Franchises.approve(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           enrollment_id
         ) do
      {:ok, _enrollment} ->
        {:noreply,
         socket
         |> load_collaborative_commerce()
         |> put_flash(:info, "Partner approved and package catalog activated.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, franchise_error(reason))}
    end
  end

  def handle_event("refresh_commerce_passport", _params, socket) do
    case CommercePassports.refresh(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id
         ) do
      {:ok, passport} ->
        {:noreply,
         socket
         |> assign_passport(passport)
         |> put_flash(:info, "Commerce passport refreshed from current evidence.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The passport could not be refreshed.")}
    end
  end

  def handle_event("appeal_reputation_signal", %{"appeal" => params}, socket) do
    case CommercePassports.appeal(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           params["signal_id"],
           params["reason"] || ""
         ) do
      {:ok, _appeal} ->
        {:noreply,
         socket
         |> load_commerce_passport()
         |> put_flash(:info, "Appeal submitted with the signal evidence attached.")}

      {:error, :invalid_appeal} ->
        {:noreply, put_flash(socket, :error, "Explain the issue in at least 10 characters.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "This signal could not be appealed.")}
    end
  end

  def handle_event("create_inventory_policy", %{"inventory_policy" => params}, socket) do
    case InventoryReservations.create_policy(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           params["offer_variant_id"],
           params
         ) do
      {:ok, _policy} ->
        {:noreply,
         socket
         |> assign(:inventory_policy_form, inventory_policy_form())
         |> load_inventory_eligibility()
         |> put_flash(:info, "Transparent inventory eligibility published.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inventory_error(reason))}
    end
  end

  def handle_event("reserve_eligible_inventory", %{"inventory_reservation" => params}, socket) do
    case InventoryReservations.reserve(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           params["policy_id"],
           params["quantity"]
         ) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> load_inventory_eligibility()
         |> put_flash(:info, "Inventory held until the displayed expiry time.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inventory_error(reason))}
    end
  end

  def handle_event("release_inventory_reservation", %{"id" => reservation_id}, socket) do
    case InventoryReservations.release(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           reservation_id
         ) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> load_inventory_eligibility()
         |> put_flash(:info, "Unused inventory returned to the supplier.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inventory_error(reason))}
    end
  end

  def handle_event("record_sales_share", %{"id" => share_id}, socket) do
    SalesSharing.record_share(
      socket.assigns.current_merchant,
      socket.assigns.current_store.id,
      share_id
    )

    {:noreply, socket |> load_sales_journey() |> load_income_goal()}
  end

  def handle_event("create_income_goal", %{"income_goal" => params}, socket) do
    attrs = Map.update(params, "target_amount", "", &cedis_to_pesewas/1)

    case IncomeGoals.create(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           attrs
         ) do
      {:ok, _goal} ->
        {:noreply,
         socket
         |> assign(:income_goal_form, income_goal_form())
         |> load_income_goal()
         |> put_flash(:info, "Your seven-day earning plan is ready.")}

      {:error, :invalid_goal} ->
        {:noreply,
         put_flash(socket, :error, "Enter a valid target, timeframe, and daily time budget.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Your income goal could not be saved.")}
    end
  end

  def handle_event("select_inbound_shipping", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(
       shipping_fulfillment_id: id,
       shipping_form: to_form(%{"tracking_number" => ""}, as: :shipment)
     )
     |> load_inbound_fulfillments()}
  end

  def handle_event("cancel_inbound_shipping", _params, socket) do
    {:noreply, socket |> assign(:shipping_fulfillment_id, nil) |> load_inbound_fulfillments()}
  end

  def handle_event("ship_inbound", %{"shipment" => params}, socket) do
    id = socket.assigns.shipping_fulfillment_id

    case InboundFulfillment.mark_shipped(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id,
           Map.get(params, "tracking_number", "")
         ) do
      {:ok, _fulfillment} ->
        {:noreply,
         socket
         |> assign(:shipping_fulfillment_id, nil)
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Shipment marked as on the way.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Shipment could not be updated.")}
    end
  end

  def handle_event("request_delivery_code", %{"id" => id}, socket) do
    case InboundFulfillment.request_delivery_code(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           id
         ) do
      {:ok, _proof} ->
        {:noreply,
         socket
         |> assign(
           delivery_fulfillment_id: id,
           delivery_form: to_form(%{"code" => ""}, as: :delivery)
         )
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Delivery code sent to the customer.")}

      {:error, :customer_phone_missing} ->
        {:noreply, put_flash(socket, :error, "This order has no customer phone number.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The delivery code could not be sent.")}
    end
  end

  def handle_event("enter_delivery_code", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(
       delivery_fulfillment_id: id,
       delivery_form: to_form(%{"code" => ""}, as: :delivery)
     )
     |> load_inbound_fulfillments()}
  end

  def handle_event("verify_delivery", %{"delivery" => params}, socket) do
    case InboundFulfillment.verify_delivery(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           socket.assigns.delivery_fulfillment_id,
           Map.get(params, "code", "")
         ) do
      {:ok, _fulfillment} ->
        {:noreply,
         socket
         |> assign(:delivery_fulfillment_id, nil)
         |> load_inbound_fulfillments()
         |> put_flash(:info, "Delivery confirmed by the customer.")}

      {:error, :invalid_code} ->
        {:noreply, put_flash(socket, :error, "That delivery code is not correct.")}

      {:error, :expired} ->
        {:noreply, put_flash(socket, :error, "That code has expired. Send a new one.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Delivery could not be confirmed.")}
    end
  end

  defp update_connection(socket, id, callback, success_message) do
    actor = socket.assigns.current_merchant

    with {:ok, connection} <- Network.get(actor, id),
         {:ok, _updated} <- callback.(actor, connection) do
      {:noreply,
       socket
       |> load_connections()
       |> load_earn_catalog()
       |> load_sales_journey()
       |> put_flash(:info, success_message)}
    else
      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You cannot perform that action.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The connection could not be updated.")}
    end
  end

  defp load_connections(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    connections =
      case Network.list_for_store(actor, store.id) do
        {:ok, rows} -> Ash.load!(rows, [:wholesaler_store, :reseller_store], authorize?: false)
        _ -> []
      end

    socket
    |> assign(:connection_count, length(connections))
    |> assign(:active_connection?, Enum.any?(connections, &(&1.status == :active)))
    |> stream(:connections, connections, reset: true)
  end

  defp load_earn_catalog(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    offers = result_rows(Offers.list_available(actor, store.id))
    listings = result_rows(ListingImporter.list(actor, store.id))
    imported_offer_ids = MapSet.new(listings, & &1.offer_id)
    available = Enum.reject(offers, &MapSet.member?(imported_offer_ids, &1.id))

    socket
    |> assign(:offer_count, length(available))
    |> assign(:listing_count, length(listings))
    |> assign(:radar_offers, offers)
    |> assign(:hustle_opportunities, Enum.map(offers, &hustle_opportunity/1))
    |> assign(:hustle_listings, listings)
    |> stream(:offers, available, reset: true)
    |> stream(:listings, listings, reset: true)
  end

  defp load_inbound_fulfillments(socket) do
    fulfillments =
      socket.assigns.current_merchant
      |> InboundFulfillment.list(socket.assigns.current_store.id)
      |> result_rows()

    socket
    |> assign(:inbound_count, length(fulfillments))
    |> stream(:inbound_fulfillments, fulfillments, reset: true)
  end

  defp load_sales_journey(socket) do
    shares =
      socket.assigns.current_merchant
      |> SalesSharing.list_for_store(socket.assigns.current_store.id)
      |> result_rows()

    share_count = Enum.reduce(shares, 0, &(&1.share_count + &2))
    click_count = Enum.reduce(shares, 0, &(&1.click_count + &2))
    order_count = Enum.reduce(shares, 0, &(&1.order_count + &2))
    revenue = Enum.reduce(shares, 0, &(&1.revenue + &2))

    delivered? =
      Enum.any?(shares, fn share ->
        Enum.any?(share.conversions, &SalesSharing.delivered_conversion?/1)
      end)

    first_money = %{
      connected: socket.assigns.active_connection?,
      listed: socket.assigns.listing_count > 0,
      shared: share_count > 0,
      sold: order_count > 0,
      fulfilled: delivered?
    }

    socket
    |> assign(:sales_share_count, length(shares))
    |> assign(:sales_click_count, click_count)
    |> assign(:sales_order_count, order_count)
    |> assign(:sales_revenue, revenue)
    |> assign(:hustle_shares, shares)
    |> assign(:first_money, first_money)
    |> stream(:sales_shares, shares, reset: true)
  end

  defp load_income_goal(socket) do
    goal =
      socket.assigns.current_merchant
      |> IncomeGoals.active(socket.assigns.current_store.id)
      |> case do
        {:ok, goal} -> goal
        _error -> nil
      end

    opportunities =
      attach_history(
        socket.assigns.hustle_opportunities,
        socket.assigns.hustle_listings,
        socket.assigns.hustle_shares
      )

    plan = if goal, do: HustlePlanner.plan(goal, opportunities), else: nil

    progress =
      if goal do
        case GoalProgress.load(
               socket.assigns.current_merchant,
               socket.assigns.current_store.id,
               goal
             ) do
          {:ok, progress} -> progress
          _error -> nil
        end
      end

    socket
    |> assign(:hustle_opportunities, opportunities)
    |> assign(:income_goal, goal)
    |> assign(:hustle_plan, plan)
    |> assign(:goal_progress, progress)
  end

  defp load_content_drafts(socket) do
    drafts =
      socket.assigns.current_merchant
      |> ContentStudio.list(socket.assigns.current_store.id)
      |> result_rows()

    socket
    |> assign(:content_draft_count, length(drafts))
    |> stream(:content_drafts, drafts, reset: true)
  end

  defp load_opportunity_radar(socket) do
    events = OpportunitySignals.recent() |> result_rows()

    radar =
      OpportunityRadar.build(
        socket.assigns[:radar_offers] || [],
        socket.assigns.hustle_listings,
        socket.assigns.hustle_shares,
        events,
        socket.assigns.current_store.id
      )
      |> Emakola.Suppliers.RadarEvaluation.rank(socket.assigns.current_store.id)

    OpportunitySignals.emit_supplier_alerts(radar)
    alerts = OpportunitySignals.supplier_alerts(socket.assigns.current_store.id) |> result_rows()

    socket
    |> assign(:opportunity_radar_count, length(radar))
    |> assign(:supplier_demand_alert_count, length(alerts))
    |> stream(:opportunity_radar, radar, reset: true)
    |> stream(:supplier_demand_alerts, alerts, reset: true)
  end

  defp load_collaborative_commerce(socket) do
    actor = socket.assigns.current_merchant
    store_id = socket.assigns.current_store.id
    campaigns = GroupBuys.list(actor, store_id) |> result_rows()
    teams = SalesTeams.list(actor, store_id) |> result_rows()
    invitations = SalesTeams.invitations(actor) |> result_rows()

    owned_packages =
      case Emakola.Suppliers.list_franchise_packages_owned_by_store(store_id,
             authorize?: false
           ) do
        {:ok, rows} -> rows
        _error -> []
      end

    available_packages = Franchises.discover(actor, store_id) |> result_rows()
    owned_offers = Offers.list_owned(actor, store_id) |> result_rows()

    socket
    |> assign(:group_buy_count, length(campaigns))
    |> assign(:sales_team_count, length(teams))
    |> assign(:franchise_package_count, length(owned_packages))
    |> assign(:available_franchise_count, length(available_packages))
    |> assign(:collaboration_owned_offers, owned_offers)
    |> stream(:group_buys, campaigns, reset: true)
    |> stream(:sales_teams, teams, reset: true)
    |> stream(:sales_team_invitations, invitations, reset: true)
    |> stream(:owned_franchise_packages, owned_packages, reset: true)
    |> stream(:available_franchise_packages, available_packages, reset: true)
  end

  defp load_commerce_passport(socket) do
    case CommercePassports.inspect(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id
         ) do
      {:ok, passport} -> assign_passport(socket, passport)
      _ -> socket |> assign(:commerce_passport, nil) |> stream(:commerce_signals, [], reset: true)
    end
  end

  defp load_inventory_eligibility(socket) do
    actor = socket.assigns.current_merchant
    store_id = socket.assigns.current_store.id
    owned = InventoryReservations.owned_policies(actor, store_id) |> result_rows()
    eligible = InventoryReservations.eligible_policies(actor, store_id) |> result_rows()
    reservations = InventoryReservations.list(actor, store_id) |> result_rows()

    forms =
      Map.new(eligible, fn policy ->
        {policy.id,
         to_form(%{"policy_id" => policy.id, "quantity" => "1"},
           as: :inventory_reservation,
           id: "inventory-reservation-#{policy.id}"
         )}
      end)

    socket
    |> assign(:inventory_reservation_forms, forms)
    |> stream(:owned_inventory_policies, owned, reset: true)
    |> stream(:eligible_inventory_policies, eligible, reset: true)
    |> stream(:inventory_reservations, reservations, reset: true)
  end

  defp assign_passport(socket, passport) do
    signals = Enum.reject(passport.signals, &(&1.status == :expired))

    forms =
      Map.new(signals, fn signal ->
        {signal.id,
         to_form(%{"signal_id" => signal.id, "reason" => ""},
           as: :appeal,
           id: "appeal-#{signal.id}"
         )}
      end)

    socket
    |> assign(:commerce_passport, passport)
    |> assign(:passport_appeal_forms, forms)
    |> stream(:commerce_signals, signals, reset: true)
  end

  defp result_rows({:ok, rows}), do: rows
  defp result_rows(_error), do: []

  defp connection_attrs(current_store_id, partner_store_id, "supply") do
    %{
      wholesaler_store_id: current_store_id,
      reseller_store_id: partner_store_id,
      requested_by_store_id: current_store_id
    }
  end

  defp connection_attrs(current_store_id, partner_store_id, _resell) do
    %{
      wholesaler_store_id: partner_store_id,
      reseller_store_id: current_store_id,
      requested_by_store_id: current_store_id
    }
  end

  defp connection_form do
    to_form(%{"partner_slug" => "", "relationship" => "resell"}, as: :connection)
  end

  defp inventory_policy_form do
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

  defp inventory_policy_options(offers) do
    for offer <- offers,
        variant <- offer.offer_variants do
      label = "#{offer.source_product.title} · #{String.slice(variant.id, 0, 6)}"
      {label, variant.id}
    end
  end

  defp inventory_error(:not_eligible), do: "Your current passport tier does not meet this rule."
  defp inventory_error(:reseller_limit_exceeded), do: "That exceeds the published reseller limit."
  defp inventory_error(:insufficient_inventory), do: "The supplier no longer has enough stock."

  defp inventory_error(:inventory_not_tracked),
    do: "The supplier must track this stock before reserving it."

  defp inventory_error(_), do: "The inventory request could not be completed."

  defp income_goal_form do
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

  defp business_command_form do
    to_form(%{"instruction" => ""}, as: :business_command)
  end

  defp starter_business_form do
    to_form(%{"niche" => "", "count" => "3"}, as: :starter_business)
  end

  defp group_buy_form do
    deadline = DateTime.add(DateTime.utc_now(), 7, :day)
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

  defp sales_team_form do
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

  defp franchise_form do
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

  defp find_listing_mapping(listings, mapping_id) do
    listings |> Enum.flat_map(& &1.listing_variants) |> Enum.find(&(&1.id == mapping_id))
  end

  defp group_buy_attrs(params, mapping) do
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

  defp local_datetime(value), do: value <> ":00Z"

  defp merchant_by_email(email) do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(email == ^String.trim(email))
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{} = merchant} -> {:ok, merchant}
      _error -> {:error, :merchant_not_found}
    end
  end

  defp percent_bps(value) do
    case Decimal.parse(String.trim(value || "")) do
      {percent, ""} ->
        bps = percent |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()
        if bps in 1..10_000, do: {:ok, bps}, else: {:error, :invalid_percent}

      _ ->
        {:error, :invalid_percent}
    end
  end

  defp group_buy_error(:price_below_supplier_floor),
    do: "The campaign price cannot underpay the supplier."

  defp group_buy_error(:deadline_must_be_future), do: "Choose a future campaign deadline."

  defp group_buy_error(:refund_deadline_invalid),
    do: "The refund deadline must be after the campaign deadline."

  defp group_buy_error(_reason), do: "The group buy could not be created."
  defp sales_team_error(:merchant_not_found), do: "No Makola merchant uses that email."

  defp sales_team_error(:split_total_must_equal_10000),
    do: "The two earnings percentages must total exactly 100%."

  defp sales_team_error(_reason), do: "The sales team could not be created."

  defp franchise_error(:package_incomplete),
    do: "Add training, brand rules, channels, and a published offer."

  defp franchise_error(_reason), do: "The micro-franchise package could not be published."

  defp group_buy_options(listings) do
    Enum.flat_map(listings, fn listing ->
      Enum.map(listing.listing_variants, fn mapping ->
        {"#{listing.reseller_product.title} — #{money(mapping.retail_price)}", mapping.id}
      end)
    end)
  end

  defp franchise_offer_options(offers),
    do: Enum.map(offers, &{&1.source_product.title, &1.id})

  defp execute_business_command(_socket, nil),
    do: {:error, "Preview an instruction before confirming it."}

  defp execute_business_command(socket, %{action: :import_products, count: count}) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    offers = Offers.list_available(actor, store.id) |> result_rows() |> Enum.take(count)

    imported =
      Enum.count(offers, fn offer ->
        match?({:ok, _listing}, ListingImporter.import(actor, store.id, offer))
      end)

    if imported > 0,
      do: {:ok, "Added #{imported} partner product#{if imported == 1, do: "", else: "s"}."},
      else: {:error, "No eligible new partner products are available."}
  end

  defp execute_business_command(socket, %{action: :create_content}) do
    case List.first(socket.assigns.hustle_listings) do
      nil ->
        {:error, "Add a partner product before creating content."}

      listing ->
        case ContentStudio.create_draft(
               socket.assigns.current_merchant,
               socket.assigns.current_store.id,
               listing.id
             ) do
          {:ok, _draft} -> {:ok, "Fact-grounded content draft created for review."}
          _error -> {:error, "The content draft could not be created."}
        end
    end
  end

  defp execute_business_command(socket, %{action: :create_sales_kit}) do
    case List.first(socket.assigns.hustle_listings) do
      nil ->
        {:error, "Add a partner product before creating a Sales Kit."}

      listing ->
        case SalesSharing.create_kit(socket.assigns.current_merchant, listing) do
          {:ok, _shares} -> {:ok, "Tracked Sales Kit links created."}
          _error -> {:error, "The Sales Kit could not be created."}
        end
    end
  end

  defp cedis_to_pesewas(value) when is_binary(value) do
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

  defp cedis_to_pesewas(value), do: value

  defp partner(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: connection.reseller_store,
      else: connection.wholesaler_store
  end

  defp incoming?(connection, current_store_id) do
    connection.status == :pending and connection.requested_by_store_id != current_store_id
  end

  defp relationship_label(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: "You supply this store",
      else: "You sell this store's products"
  end

  defp status_classes(:active), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp status_classes(:pending), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  defp status_classes(:suspended), do: "bg-slate-100 text-slate-600 ring-slate-500/20"
  defp status_classes(:rejected), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp status_classes(:terminated), do: "bg-slate-100 text-slate-500 ring-slate-500/20"

  defp fulfillment_status_classes(:pending), do: "bg-amber-50 text-amber-700"
  defp fulfillment_status_classes(:notified), do: "bg-blue-50 text-blue-700"
  defp fulfillment_status_classes(:shipped), do: "bg-violet-50 text-violet-700"
  defp fulfillment_status_classes(:delivered), do: "bg-emerald-50 text-emerald-700"
  defp fulfillment_status_classes(:cancelled), do: "bg-slate-100 text-slate-500"

  defp content_status_classes(:draft), do: "bg-amber-50 text-amber-700"
  defp content_status_classes(:approved), do: "bg-emerald-50 text-emerald-700"
  defp content_status_classes(:rejected), do: "bg-rose-50 text-rose-700"
  defp content_status_classes(:stale), do: "bg-slate-100 text-slate-600"

  defp shipment_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id
  defp delivery_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id

  defp customer_city(order) do
    address = order.shipping_address || %{}
    Map.get(address, "city") || Map.get(address, :city) || "Delivery address on order"
  end

  defp lead_image(offer), do: List.first(offer.source_product.images)

  defp earning_range(offer) do
    earnings = Enum.map(offer.offer_variants, &(&1.suggested_retail_price - &1.supplier_price))

    case Enum.min_max(earnings, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  # The supplier's own returns/warranty commitment, reusing the same formatter
  # the storefront uses — a SupplierOffer carries the same `returns_window_days`
  # and `warranty_months` shape as a merchant's page content, so "30-day
  # returns" means the same thing on both sides of the deal.
  defp supplier_terms(offer), do: Emakola.Themes.Terms.badges(%{page_content: offer})

  defp supplier_backing_line(offer) do
    case supplier_terms(offer) do
      [] -> "Nothing stated — any returns or warranty you offer, you fund yourself."
      badges -> Enum.join(badges, " · ")
    end
  end

  defp hustle_opportunity(offer) do
    terms =
      Enum.max_by(offer.offer_variants, &(&1.suggested_retail_price - &1.supplier_price), fn ->
        nil
      end)

    gross = if terms, do: terms.suggested_retail_price - terms.supplier_price, else: 0
    earning = div(gross * 9_000, 10_000)

    %{
      id: offer.id,
      title: offer.source_product.title,
      supplier_price: if(terms, do: terms.supplier_price, else: 0),
      retail_price: if(terms, do: terms.suggested_retail_price, else: 0),
      platform_fee: gross - earning,
      earning: earning,
      ordered: 0,
      fulfilled: 0,
      refunded: 0,
      status: if(offer.status == :published, do: :active, else: :paused)
    }
  end

  defp attach_history(opportunities, listings, shares) do
    offer_by_product = Map.new(listings, &{&1.reseller_product_id, &1.offer_id})

    stats =
      Enum.reduce(shares, %{}, fn share, acc ->
        case Map.get(offer_by_product, share.product_id) do
          nil ->
            acc

          offer_id ->
            current = Map.get(acc, offer_id, %{ordered: 0, fulfilled: 0, refunded: 0})
            conversions = share.conversions

            Map.put(acc, offer_id, %{
              ordered: current.ordered + length(conversions),
              fulfilled:
                current.fulfilled + Enum.count(conversions, &SalesSharing.delivered_conversion?/1),
              refunded: current.refunded + Enum.count(conversions, &refunded_conversion?/1)
            })
        end
      end)

    Enum.map(opportunities, &Map.merge(&1, Map.get(stats, &1.id, %{})))
  end

  defp refunded_conversion?(conversion) do
    case Emakola.Payments.get_payment_by_order(conversion.order_id, authorize?: false) do
      {:ok, payment} -> payment.refunded_amount > 0
      _error -> false
    end
  end

  defp retail_range(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)

    case Enum.min_max(prices, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  defp money(pesewas), do: "GH₵#{:erlang.float_to_binary(pesewas / 100, decimals: 2)}"

  defp sales_share_url(share), do: SalesSharing.url(share)
  defp sales_share_message(share), do: SalesSharing.message(share)

  defp whatsapp_share_url(share),
    do: "https://wa.me/?text=#{URI.encode_www_form(sales_share_message(share))}"

  defp facebook_share_url(share),
    do:
      "https://www.facebook.com/sharer/sharer.php?u=#{URI.encode_www_form(sales_share_url(share))}"

  defp channel_label(:whatsapp), do: "WhatsApp"
  defp channel_label(:facebook), do: "Facebook"
  defp channel_label(:copy_link), do: "Copy link"

  defp channel_icon(:whatsapp), do: "hero-chat-bubble-left-right"
  defp channel_icon(:facebook), do: "hero-user-group"
  defp channel_icon(:copy_link), do: "hero-link"

  defp next_action_message(:publish), do: "Start by adding one recommended partner product."

  defp next_action_message(:create_sales_kit),
    do: "Turn your first product into tracked share links."

  defp next_action_message(:share), do: "Share a tracked link where customers already know you."

  defp next_action_message(:follow_up),
    do: "People are viewing your links—follow up and answer questions."

  defp next_action_message(:fulfill),
    do: "A customer ordered. Help the supplier complete delivery successfully."

  defp journey_step(first_money, key, label, description) do
    %{
      key: key,
      complete?: Map.get(first_money, key, false),
      label: label,
      description: description
    }
  end

  @impl true
  def render(assigns) do
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

      <section
        id="hustle-autopilot"
        aria-labelledby="hustle-autopilot-heading"
        class="overflow-hidden rounded-3xl border border-violet-200 bg-gradient-to-br from-violet-50 via-white to-emerald-50 p-6 shadow-sm sm:p-8"
      >
        <div class="flex items-start gap-4">
          <div class="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-violet-600 text-white shadow-lg shadow-violet-200">
            <.icon name="hero-rocket-launch" class="size-6" />
          </div>
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-700">
              Hustle Autopilot
            </span>
            <h2 id="hustle-autopilot-heading" class="mt-1 text-2xl font-bold text-slate-950">
              Turn an income goal into today's next action
            </h2>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Makola uses real partner-product economics to estimate the sales needed and build a focused seven-day plan. Income is never guaranteed.
            </p>
          </div>
        </div>

        <%= if @income_goal do %>
          <div id="active-income-goal" class="mt-7 grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
            <div class="rounded-2xl bg-slate-950 p-5 text-white shadow-xl">
              <p class="text-xs font-bold uppercase tracking-wider text-violet-300">Your target</p>
              <p id="income-goal-target" class="mt-2 text-3xl font-black">
                {money(@income_goal.target_amount)}
              </p>
              <p class="mt-1 text-sm text-slate-300">
                over {@income_goal.timeframe_days} days · {@income_goal.daily_minutes} minutes/day
              </p>
              <div class="mt-5 grid grid-cols-2 gap-3">
                <div class="rounded-xl bg-white/10 p-3">
                  <p class="text-[10px] uppercase text-slate-400">Estimated sales</p>
                  <p id="income-goal-required-sales" class="mt-1 text-xl font-bold">
                    {@hustle_plan.required_sales}
                  </p>
                </div>
                <div class="rounded-xl bg-white/10 p-3">
                  <p class="text-[10px] uppercase text-slate-400">Per day</p>
                  <p class="mt-1 text-xl font-bold">{@hustle_plan.daily_sales_target}</p>
                </div>
              </div>
              <p id="income-goal-disclaimer" class="mt-4 text-xs leading-5 text-slate-400">
                {@hustle_plan.disclaimer}
              </p>
            </div>

            <div>
              <div id="hustle-recommendations" class="mb-6">
                <h3 class="text-sm font-bold text-slate-900">Why these products</h3>
                <div class="mt-3 space-y-2">
                  <article
                    :for={item <- Enum.take(@hustle_plan.recommended, 3)}
                    id={"hustle-recommendation-#{item.id}"}
                    class="rounded-xl border border-violet-100 bg-white p-3 shadow-sm"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <p class="text-sm font-bold text-slate-900">{item.title}</p>
                      <span class="rounded-full bg-violet-50 px-2 py-1 text-[10px] font-bold uppercase text-violet-700">
                        {item.confidence} evidence
                      </span>
                    </div>
                    <dl class="mt-3 grid grid-cols-4 gap-2 text-xs">
                      <div>
                        <dt class="text-slate-400">Supplier</dt>
                        <dd class="font-bold text-slate-700">{money(item.supplier_price)}</dd>
                      </div>
                      <div>
                        <dt class="text-slate-400">Customer</dt>
                        <dd class="font-bold text-slate-700">{money(item.retail_price)}</dd>
                      </div>
                      <div>
                        <dt class="text-slate-400">Fee</dt>
                        <dd class="font-bold text-slate-700">{money(item.platform_fee)}</dd>
                      </div>
                      <div>
                        <dt class="text-emerald-600">You earn</dt>
                        <dd class="font-bold text-emerald-700">{money(item.earning)}</dd>
                      </div>
                    </dl>
                    <p class="mt-2 text-[11px] leading-4 text-slate-500">{item.reason}</p>
                  </article>
                </div>
              </div>
              <h3 class="text-sm font-bold text-slate-900">Your next seven actions</h3>
              <ol id="hustle-plan-actions" class="mt-3 space-y-2">
                <li
                  :for={action <- @hustle_plan.actions}
                  id={"hustle-action-#{action.day}"}
                  class="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-3"
                >
                  <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-violet-100 text-xs font-black text-violet-700">
                    {action.day}
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="text-sm font-semibold text-slate-800">{action.message}</p>
                    <p class="text-xs text-slate-400">About {action.minutes} minutes</p>
                  </div>
                </li>
              </ol>
            </div>
          </div>

          <div
            :if={@goal_progress}
            id="income-goal-progress"
            class="mt-6 rounded-2xl border border-emerald-200 bg-white p-5 shadow-sm"
          >
            <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p class="text-xs font-bold uppercase tracking-wider text-emerald-700">
                  Real fulfilled earnings
                </p>
                <p id="goal-net-earned" class="mt-1 text-2xl font-black text-slate-950">
                  {money(@goal_progress.net_earned)}
                </p>
                <p class="text-xs text-slate-500">
                  {money(@goal_progress.remaining)} remaining toward this scenario
                </p>
              </div>
              <p id="goal-progress-percent" class="text-3xl font-black text-emerald-700">
                {@goal_progress.percent}%
              </p>
            </div>
            <div class="mt-4 h-2 overflow-hidden rounded-full bg-slate-100">
              <div
                class="h-full rounded-full bg-emerald-500 transition-all duration-500"
                style={"width: #{@goal_progress.percent}%"}
              >
              </div>
            </div>
            <dl class="mt-5 grid grid-cols-3 gap-3 sm:grid-cols-6">
              <div
                :for={
                  {label, value} <- [
                    {"Published", @goal_progress.published},
                    {"Shared", @goal_progress.shared},
                    {"Clicked", @goal_progress.clicked},
                    {"Ordered", @goal_progress.ordered},
                    {"Fulfilled", @goal_progress.fulfilled},
                    {"Refunded", @goal_progress.refunded}
                  ]
                }
                class="rounded-xl bg-slate-50 p-3 text-center"
              >
                <dt class="text-[10px] font-bold uppercase text-slate-400">{label}</dt>
                <dd class="mt-1 text-lg font-black text-slate-800">{value}</dd>
              </div>
            </dl>
            <div
              id="goal-next-action"
              class="mt-5 flex flex-wrap items-center gap-3 border-t border-slate-100 pt-4"
            >
              <p class="mr-auto text-sm font-semibold text-slate-700">
                {next_action_message(@goal_progress.next_action)}
              </p>
              <button
                :if={@goal_progress.next_action == :publish && @hustle_opportunities != []}
                id="goal-publish-product"
                phx-click="import_offer"
                phx-value-id={List.first(@hustle_opportunities).id}
                class="rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-violet-700"
              >
                Add recommended product
              </button>
              <button
                :if={@goal_progress.next_action == :create_sales_kit && @hustle_listings != []}
                id="goal-create-sales-kit"
                phx-click="create_sales_kit"
                phx-value-id={List.first(@hustle_listings).id}
                class="rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-violet-700"
              >
                Create Sales Kit
              </button>
              <a
                :if={@goal_progress.next_action in [:share, :follow_up] && @hustle_shares != []}
                id="goal-share-now"
                href={whatsapp_share_url(List.first(@hustle_shares))}
                phx-click="record_sales_share"
                phx-value-id={List.first(@hustle_shares).id}
                target="_blank"
                rel="noopener"
                class="rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-emerald-700"
              >
                Share now
              </a>
              <a
                :if={@goal_progress.next_action == :fulfill}
                id="goal-track-fulfillment"
                href="#first-money-journey"
                class="rounded-xl bg-amber-500 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-amber-600"
              >
                Track fulfillment
              </a>
            </div>
          </div>
        <% else %>
          <.form
            for={@income_goal_form}
            id="income-goal-form"
            phx-submit="create_income_goal"
            class="mt-7 grid gap-4 rounded-2xl border border-white/80 bg-white/80 p-5 shadow-sm backdrop-blur md:grid-cols-2 xl:grid-cols-4 xl:items-end"
          >
            <.input
              field={@income_goal_form[:target_amount]}
              type="number"
              min="1"
              step="0.01"
              label="Income target (GH₵)"
              required
            />
            <.input
              field={@income_goal_form[:timeframe_days]}
              type="select"
              label="Timeframe"
              options={[{"14 days", "14"}, {"30 days", "30"}, {"60 days", "60"}, {"90 days", "90"}]}
            />
            <.input
              field={@income_goal_form[:daily_minutes]}
              type="select"
              label="Daily time"
              options={[
                {"20 minutes", "20"},
                {"45 minutes", "45"},
                {"90 minutes", "90"},
                {"2 hours", "120"}
              ]}
            />
            <button
              id="build-income-plan"
              type="submit"
              class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-violet-600 px-5 text-sm font-bold text-white shadow-md transition hover:-translate-y-0.5 hover:bg-violet-700"
            >
              <.icon name="hero-sparkles" class="size-4" /> Build my plan
            </button>
          </.form>
        <% end %>
      </section>

      <section
        id="collaborative-commerce"
        aria-labelledby="collaborative-commerce-heading"
        class="space-y-6 rounded-3xl border border-fuchsia-200 bg-fuchsia-50/40 p-6 shadow-sm sm:p-8"
      >
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-fuchsia-700">
            Collaborative Commerce
          </span>
          <h2 id="collaborative-commerce-heading" class="mt-1 text-2xl font-bold text-slate-950">
            Contribute demand, skills, or a proven playbook—not recruitment
          </h2>
          <p class="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
            Group buys have visible thresholds and refund dates. Team earnings total exactly 100% and require personal consent. Micro-franchises reward product sales only—never downlines.
          </p>
        </div>

        <div class="grid gap-5 xl:grid-cols-3">
          <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
            <h3 class="font-bold text-slate-900">Open a group buy</h3>
            <p class="mt-1 text-xs text-slate-500">
              Customers commit to one variant at a locked price.
            </p>
            <.form
              for={@group_buy_form}
              id="group-buy-form"
              phx-submit="create_group_buy"
              class="mt-4 space-y-3"
            >
              <.input
                field={@group_buy_form[:listing_variant_id]}
                type="select"
                label="Product variant"
                prompt="Choose a product"
                options={group_buy_options(@hustle_listings)}
                required
              />
              <.input field={@group_buy_form[:title]} type="text" label="Campaign name" required />
              <div class="grid grid-cols-2 gap-3">
                <.input
                  field={@group_buy_form[:threshold_quantity]}
                  type="number"
                  min="2"
                  max="1000"
                  label="Threshold"
                  required
                /><.input
                  field={@group_buy_form[:unit_price]}
                  type="number"
                  min="0.01"
                  step="0.01"
                  label="Price (GH₵)"
                  required
                />
              </div>
              <.input
                field={@group_buy_form[:deadline]}
                type="datetime-local"
                label="Commitment deadline"
                required
              />
              <.input
                field={@group_buy_form[:refund_deadline]}
                type="datetime-local"
                label="Refund completed by"
                required
              />
              <button
                id="create-group-buy"
                type="submit"
                class="w-full rounded-xl bg-fuchsia-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
              >
                Open protected group buy
              </button>
            </.form>
            <div id="group-buy-campaigns" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, campaign} <- @streams.group_buys}
                id={dom_id}
                class="rounded-xl bg-fuchsia-50 p-3 text-xs"
              >
                <p class="font-bold text-fuchsia-900">{campaign.title}</p>
                <p class="mt-1 text-fuchsia-800">
                  {campaign.committed_quantity}/{campaign.threshold_quantity} paid · {money(
                    campaign.unit_price
                  )} · {campaign.status}
                </p>
                <p class="mt-1 text-fuchsia-700">
                  Refund by {Calendar.strftime(campaign.refund_deadline, "%d %b %Y %H:%M UTC")} if threshold is missed.
                </p>
              </article>
            </div>
          </div>

          <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
            <h3 class="font-bold text-slate-900">Create a flat sales team</h3>
            <p class="mt-1 text-xs text-slate-500">
              One collaborator, declared role, exact split; expandable through the service boundary.
            </p>
            <.form
              for={@sales_team_form}
              id="sales-team-form"
              phx-submit="create_sales_team"
              class="mt-4 space-y-3"
            >
              <.input field={@sales_team_form[:name]} type="text" label="Team name" required />
              <.input
                field={@sales_team_form[:collaborator_email]}
                type="email"
                label="Collaborator's Makola email"
                required
              />
              <.input
                field={@sales_team_form[:collaborator_role]}
                type="select"
                label="Declared role"
                options={[
                  {"Seller", "seller"},
                  {"Content", "content"},
                  {"Customer support", "support"}
                ]}
              />
              <div class="grid grid-cols-2 gap-3">
                <.input
                  field={@sales_team_form[:owner_percent]}
                  type="number"
                  min="1"
                  max="99"
                  step="0.01"
                  label="Your %"
                  required
                /><.input
                  field={@sales_team_form[:collaborator_percent]}
                  type="number"
                  min="1"
                  max="99"
                  step="0.01"
                  label="Their %"
                  required
                />
              </div>
              <button
                id="create-sales-team"
                type="submit"
                class="w-full rounded-xl bg-slate-950 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
              >
                Send consent invitation
              </button>
            </.form>
            <div id="sales-team-invitations" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, member} <- @streams.sales_team_invitations}
                id={dom_id}
                class="rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs"
              >
                <p class="font-bold text-amber-900">
                  {member.team.name}: {member.role} · {member.split_bps / 100}%
                </p>
                <button
                  id={"accept-sales-team-#{member.id}"}
                  phx-click="accept_sales_team"
                  phx-value-id={member.id}
                  class="mt-2 rounded-lg bg-amber-700 px-3 py-1.5 font-bold text-white"
                >
                  Accept role and split
                </button>
              </article>
            </div>
            <div id="sales-teams" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, team} <- @streams.sales_teams}
                id={dom_id}
                class="rounded-xl bg-slate-50 p-3 text-xs"
              >
                <p class="font-bold text-slate-800">{team.name}</p>
                <p class="mt-1 text-slate-500">{length(team.members)} flat members · {team.status}</p>
                <p class="mt-2 break-all rounded-lg bg-white px-2 py-1.5 font-mono text-[10px] text-emerald-700">
                  {EmakolaWeb.Endpoint.url()}/s/{@current_store.slug}?sales_team={team.id}
                </p>
              </article>
            </div>
          </div>

          <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
            <h3 class="font-bold text-slate-900">Package a micro-franchise</h3>
            <p class="mt-1 text-xs text-slate-500">
              For suppliers: training, rules, channels, territory, and sales commission.
            </p>
            <.form
              for={@franchise_form}
              id="franchise-package-form"
              phx-submit="create_franchise_package"
              class="mt-4 space-y-3"
            >
              <.input field={@franchise_form[:name]} type="text" label="Package name" required />
              <.input
                field={@franchise_form[:offer_id]}
                type="select"
                prompt="Choose your published offer"
                label="Product offer"
                options={franchise_offer_options(@collaboration_owned_offers)}
                required
              />
              <.input
                field={@franchise_form[:training]}
                type="textarea"
                label="Required training"
                required
              />
              <.input
                field={@franchise_form[:brand_rules]}
                type="textarea"
                label="Brand and claims rules"
                required
              />
              <.input field={@franchise_form[:territory]} type="text" label="Territory (optional)" />
              <.input
                field={@franchise_form[:commission_bps]}
                type="number"
                min="1"
                max="10000"
                label="Commission (basis points)"
                required
              />
              <input type="hidden" name="franchise[channel_permissions][]" value="storefront" /><input
                type="hidden"
                name="franchise[channel_permissions][]"
                value="whatsapp"
              />
              <button
                id="create-franchise-package"
                type="submit"
                class="w-full rounded-xl bg-fuchsia-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
              >
                Publish product-sales package
              </button>
            </.form>
            <div id="owned-franchise-packages" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, package} <- @streams.owned_franchise_packages}
                id={dom_id}
                class="rounded-xl border border-fuchsia-100 bg-fuchsia-50 p-3 text-xs"
              >
                <p class="font-bold text-fuchsia-950">{package.name}</p>
                <div id={"franchise-enrollments-#{package.id}"} class="mt-2 space-y-2">
                  <div
                    :for={enrollment <- package.enrollments}
                    id={"franchise-enrollment-#{enrollment.id}"}
                    class="flex items-center justify-between gap-3 rounded-lg bg-white p-2"
                  >
                    <span>{enrollment.reseller_store.name} · {enrollment.status}</span>
                    <button
                      :if={enrollment.status == :applied}
                      id={"approve-franchise-#{enrollment.id}"}
                      phx-click="approve_franchise"
                      phx-value-id={enrollment.id}
                      class="rounded-lg bg-fuchsia-700 px-3 py-1.5 font-bold text-white transition hover:bg-fuchsia-600"
                    >
                      Approve and activate catalog
                    </button>
                    <span :if={enrollment.status == :approved} class="font-bold text-emerald-700">
                      {length(enrollment.activated_listing_ids)} products active
                    </span>
                  </div>
                </div>
              </article>
            </div>
            <div id="available-franchise-packages" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, package} <- @streams.available_franchise_packages}
                id={dom_id}
                class="rounded-xl bg-emerald-50 p-3 text-xs"
              >
                <p class="font-bold text-emerald-900">{package.name}</p>
                <p class="mt-1 text-emerald-800">
                  {package.commission_bps / 100}% product-sales commission · {package.territory ||
                    "Open territory"}
                </p>
                <button
                  id={"apply-franchise-#{package.id}"}
                  phx-click="apply_franchise"
                  phx-value-id={package.id}
                  class="mt-2 rounded-lg bg-emerald-700 px-3 py-1.5 font-bold text-white"
                >
                  Accept terms and apply
                </button>
              </article>
            </div>
          </div>
        </div>
      </section>

      <section
        :if={@commerce_passport}
        id="commerce-passport"
        class="rounded-3xl border border-indigo-200 bg-gradient-to-br from-indigo-950 to-slate-950 p-6 text-white shadow-xl sm:p-8"
      >
        <div class="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-indigo-300">
              Portable commerce passport
            </p>
            <div class="mt-2 flex items-end gap-3">
              <span id="passport-score" class="text-5xl font-black">{@commerce_passport.score}</span>
              <span
                id="passport-tier"
                class="mb-1 rounded-full bg-white/10 px-3 py-1 text-sm font-bold capitalize"
              >
                {@commerce_passport.tier}
              </span>
            </div>
            <p class="mt-3 max-w-2xl text-sm leading-6 text-indigo-100">
              Built only from fulfilled orders, service outcomes, refunds, and verified supplier training. Every signal below has evidence, a reason code, and an expiry date.
            </p>
          </div>
          <button
            id="refresh-commerce-passport"
            phx-click="refresh_commerce_passport"
            class="rounded-xl bg-indigo-300 px-4 py-2.5 text-sm font-black text-indigo-950 transition hover:-translate-y-0.5 hover:bg-indigo-200"
          >
            Refresh evidence
          </button>
        </div>

        <div id="commerce-signals" phx-update="stream" class="mt-6 grid gap-3 lg:grid-cols-2">
          <article
            :for={{dom_id, signal} <- @streams.commerce_signals}
            id={dom_id}
            class="rounded-2xl border border-white/10 bg-white/5 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-bold capitalize">
                  {signal.kind |> Atom.to_string() |> String.replace("_", " ")}
                </p>
                <p class="mt-1 font-mono text-[11px] text-indigo-300">{signal.reason_code}</p>
              </div>
              <span class={[
                "rounded-full px-2 py-1 text-[10px] font-bold uppercase",
                if(signal.impact >= 0,
                  do: "bg-emerald-400/15 text-emerald-200",
                  else: "bg-rose-400/15 text-rose-200"
                )
              ]}>
                {if(signal.impact >= 0, do: "+", else: "")}{signal.impact} pts
              </span>
            </div>
            <p class="mt-3 text-xs text-indigo-100">Evidence: {Jason.encode!(signal.evidence)}</p>
            <p class="mt-1 text-[11px] text-indigo-300">
              Expires {Calendar.strftime(signal.expires_at, "%d %b %Y")}
            </p>
            <.form
              :if={signal.status == :active}
              for={Map.fetch!(@passport_appeal_forms, signal.id)}
              id={"passport-appeal-form-#{signal.id}"}
              phx-submit="appeal_reputation_signal"
              class="mt-3 flex items-end gap-2"
            >
              <.input field={Map.fetch!(@passport_appeal_forms, signal.id)[:signal_id]} type="hidden" />
              <.input
                field={Map.fetch!(@passport_appeal_forms, signal.id)[:reason]}
                type="text"
                label="Challenge this evidence"
                placeholder="Explain what is wrong or missing"
                class="min-w-0 flex-1 rounded-lg border border-white/20 bg-white px-3 py-2 text-xs text-slate-950"
              />
              <button class="rounded-lg border border-indigo-300 px-3 py-2 text-xs font-bold text-indigo-100 hover:bg-white/10">
                Appeal
              </button>
            </.form>
            <p :if={signal.status == :appealed} class="mt-3 text-xs font-bold text-amber-200">
              Appeal open — this signal is flagged for review.
            </p>
          </article>
        </div>
      </section>

      <section
        id="inventory-eligibility"
        class="rounded-3xl border border-amber-200 bg-amber-50/70 p-6 shadow-sm sm:p-8"
      >
        <div class="grid gap-6 xl:grid-cols-2">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">Supplier rules</p>
            <h2 class="mt-1 text-2xl font-black text-slate-950">Reserve stock by transparent tier</h2>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              Publish the minimum passport tier, exact unit cap, reason code, and automatic expiry. Held stock is removed atomically and unused units return automatically.
            </p>
            <.form
              for={@inventory_policy_form}
              id="inventory-policy-form"
              phx-submit="create_inventory_policy"
              class="mt-5 grid gap-3 sm:grid-cols-2"
            >
              <.input
                field={@inventory_policy_form[:offer_variant_id]}
                type="select"
                label="Offer variant"
                prompt="Choose tracked stock"
                options={inventory_policy_options(@collaboration_owned_offers)}
                required
              />
              <.input
                field={@inventory_policy_form[:minimum_tier]}
                type="select"
                label="Minimum tier"
                options={[{"Starter", "starter"}, {"Reliable", "reliable"}, {"Proven", "proven"}]}
              />
              <.input
                field={@inventory_policy_form[:max_quantity_per_reseller]}
                type="number"
                min="1"
                label="Unit cap per reseller"
              />
              <.input
                field={@inventory_policy_form[:reservation_hours]}
                type="number"
                min="1"
                max="720"
                label="Hold duration (hours)"
              />
              <button
                id="publish-inventory-policy"
                class="sm:col-span-2 rounded-xl bg-amber-600 px-4 py-2.5 text-sm font-black text-white transition hover:bg-amber-500"
              >
                Publish eligibility rule
              </button>
            </.form>
            <div id="owned-inventory-policies" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, policy} <- @streams.owned_inventory_policies}
                id={dom_id}
                class="rounded-xl bg-white p-3 text-xs text-slate-700"
              >
                <p class="font-bold text-slate-950">{policy.reason_code}</p>
                <p class="mt-1 capitalize">
                  {policy.minimum_tier}+ · up to {policy.max_quantity_per_reseller} units · {policy.reservation_hours}h
                </p>
              </article>
            </div>
          </div>

          <div>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">
              Your eligible holds
            </p>
            <div id="eligible-inventory-policies" phx-update="stream" class="mt-3 space-y-3">
              <p
                id="eligible-inventory-empty"
                class="hidden only:block rounded-xl border border-dashed border-emerald-200 bg-white p-4 text-sm text-slate-500"
              >
                No connected supplier rule currently matches your passport tier.
              </p>
              <article
                :for={{dom_id, policy} <- @streams.eligible_inventory_policies}
                id={dom_id}
                class="rounded-2xl border border-emerald-200 bg-white p-4"
              >
                <p class="text-sm font-black text-slate-950">
                  {policy.offer_variant.offer.source_product.title}
                </p>
                <p class="mt-1 font-mono text-[11px] text-emerald-700">{policy.reason_code}</p>
                <p class="mt-1 text-xs text-slate-500 capitalize">
                  Requires {policy.minimum_tier}+ · cap {policy.max_quantity_per_reseller} · expires after {policy.reservation_hours}h
                </p>
                <.form
                  for={Map.fetch!(@inventory_reservation_forms, policy.id)}
                  id={"reserve-inventory-form-#{policy.id}"}
                  phx-submit="reserve_eligible_inventory"
                  class="mt-3 flex items-end gap-2"
                >
                  <.input
                    field={Map.fetch!(@inventory_reservation_forms, policy.id)[:policy_id]}
                    type="hidden"
                  />
                  <.input
                    field={Map.fetch!(@inventory_reservation_forms, policy.id)[:quantity]}
                    type="number"
                    min="1"
                    max={policy.max_quantity_per_reseller}
                    label="Units"
                    class="w-24 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
                  />
                  <button class="rounded-lg bg-emerald-700 px-3 py-2.5 text-xs font-bold text-white hover:bg-emerald-600">
                    Hold stock
                  </button>
                </.form>
              </article>
            </div>
            <div id="inventory-reservations" phx-update="stream" class="mt-4 space-y-2">
              <article
                :for={{dom_id, reservation} <- @streams.inventory_reservations}
                id={dom_id}
                class="flex items-center justify-between gap-3 rounded-xl bg-slate-950 p-3 text-xs text-white"
              >
                <div>
                  <p class="font-bold">
                    {reservation.quantity - reservation.consumed_quantity} of {reservation.quantity} held · {reservation.status}
                  </p>
                  <p class="mt-1 text-slate-400">
                    {reservation.reason_code} · until {Calendar.strftime(
                      reservation.expires_at,
                      "%d %b %H:%M"
                    )}
                  </p>
                </div>
                <button
                  :if={reservation.status == :active}
                  id={"release-inventory-#{reservation.id}"}
                  phx-click="release_inventory_reservation"
                  phx-value-id={reservation.id}
                  class="rounded-lg border border-slate-600 px-3 py-1.5 font-bold hover:bg-slate-800"
                >
                  Release
                </button>
              </article>
            </div>
          </div>
        </div>
      </section>

      <section
        id="opportunity-radar"
        aria-labelledby="opportunity-radar-heading"
        class="rounded-3xl border border-sky-200 bg-sky-50/60 p-6 shadow-sm sm:p-8"
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-sky-700">
              Live Opportunity Radar
            </span>
            <h2 id="opportunity-radar-heading" class="mt-1 text-2xl font-bold text-slate-950">
              See demand without exposing customers
            </h2>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Searches are fingerprinted, locations appear only after three attributed orders, and every price stays inside supplier bounds with no scarcity surcharge.
            </p>
          </div>
          <button
            id="refresh-opportunity-radar"
            phx-click="refresh_opportunity_radar"
            class="inline-flex h-10 items-center justify-center gap-2 rounded-xl border border-sky-200 bg-white px-4 text-xs font-bold text-sky-800 transition hover:bg-sky-100"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Refresh signals
          </button>
        </div>

        <div id="opportunity-radar-items" phx-update="stream" class="mt-6 grid gap-4 lg:grid-cols-2">
          <div
            id="opportunity-radar-empty"
            class="hidden only:block rounded-2xl border border-dashed border-sky-200 bg-white p-8 text-center lg:col-span-2"
          >
            <p class="text-sm font-semibold text-slate-700">
              Connect to a supplier to begin collecting privacy-safe opportunity signals.
            </p>
          </div>
          <article
            :for={{dom_id, item} <- @streams.opportunity_radar}
            id={dom_id}
            class="rounded-2xl border border-sky-100 bg-white p-5 shadow-sm"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <h3 class="font-bold text-slate-900">{item.title}</h3>
                <p class="mt-1 text-xs text-slate-400">{item.freshness.label}</p>
              </div>
              <span class="rounded-full bg-sky-50 px-2.5 py-1 text-[10px] font-bold uppercase text-sky-700">
                {item.confidence} confidence
              </span>
            </div>
            <p class="mt-4 text-xs leading-5 text-slate-600">{item.explanation}</p>
            <dl class="mt-4 grid grid-cols-4 gap-2">
              <div class="rounded-xl bg-slate-50 p-2 text-center">
                <dt class="text-[9px] font-bold uppercase text-slate-400">Views</dt>
                <dd class="mt-1 font-black text-slate-800">{item.views}</dd>
              </div>
              <div class="rounded-xl bg-slate-50 p-2 text-center">
                <dt class="text-[9px] font-bold uppercase text-slate-400">Searches</dt>
                <dd class="mt-1 font-black text-slate-800">{item.searches}</dd>
              </div>
              <div class="rounded-xl bg-slate-50 p-2 text-center">
                <dt class="text-[9px] font-bold uppercase text-slate-400">Fulfilled</dt>
                <dd class="mt-1 font-black text-emerald-700">{item.fulfilled}</dd>
              </div>
              <div class="rounded-xl bg-slate-50 p-2 text-center">
                <dt class="text-[9px] font-bold uppercase text-slate-400">Stock</dt>
                <dd class="mt-1 font-black text-slate-800">{item.stock}</dd>
              </div>
            </dl>
            <div class="mt-4 rounded-xl border border-emerald-100 bg-emerald-50 p-3">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[10px] font-bold uppercase text-emerald-700">
                    Ethical recommended price
                  </p>
                  <p class="mt-1 text-lg font-black text-emerald-800">{money(item.pricing.price)}</p>
                </div>
                <span class="rounded-full bg-white px-2 py-1 text-[10px] font-bold text-emerald-700">
                  0 scarcity surcharge
                </span>
              </div>
              <p class="mt-2 text-[11px] leading-4 text-emerald-900/70">{item.pricing.reason}</p>
            </div>
            <p :if={item.regions != []} class="mt-3 text-xs text-slate-500">
              Privacy-safe demand regions: {Enum.map_join(item.regions, ", ", fn {region, count} ->
                "#{region} (#{count})"
              end)}
            </p>
          </article>
        </div>

        <div
          :if={@supplier_demand_alert_count > 0}
          id="supplier-demand-alerts"
          class="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5"
        >
          <p class="text-xs font-bold uppercase tracking-wider text-amber-800">
            Supplier demand alerts
          </p>
          <div id="supplier-demand-alert-items" phx-update="stream" class="mt-3 space-y-2">
            <article
              :for={{dom_id, alert} <- @streams.supplier_demand_alerts}
              id={dom_id}
              class="rounded-xl bg-white p-3 text-sm text-slate-700 shadow-sm"
            >
              <span class="font-bold">{alert.metadata["title"]}</span>
              received {alert.metadata["views"]} views and {alert.metadata["matched_searches"]} matched searches but no orders in the {alert.metadata[
                "window_days"
              ]}-day window. Review price, content, availability, or trust signals.
            </article>
          </div>
        </div>
      </section>

      <section
        id="business-in-a-box"
        aria-labelledby="business-command-heading"
        class="rounded-3xl border border-cyan-200 bg-gradient-to-br from-cyan-50 to-white p-6 shadow-sm sm:p-8"
      >
        <div class="flex items-start gap-4">
          <div class="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-cyan-600 text-white">
            <.icon name="hero-microphone" class="size-5" />
          </div>
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-cyan-700">
              Business-in-a-Box
            </span>
            <h2 id="business-command-heading" class="mt-1 text-xl font-bold text-slate-950">
              Say what you want to build
            </h2>
            <p class="mt-1 text-sm text-slate-600">
              Voice becomes editable text. Makola always shows the exact action and waits for confirmation before changing your store.
            </p>
          </div>
        </div>

        <.form
          for={@business_command_form}
          id="business-command-form"
          phx-submit="preview_business_command"
          class="mt-6"
        >
          <div
            id="voice-command-control"
            phx-hook=".VoiceCommand"
            class="flex flex-col gap-3 sm:flex-row"
          >
            <.input
              field={@business_command_form[:instruction]}
              type="text"
              placeholder="Add three products, create a Sales Kit…"
              required
              class="h-12 w-full rounded-xl border border-cyan-200 bg-white px-4 text-sm text-slate-900 outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
            />
            <button
              id="voice-command-button"
              type="button"
              class="inline-flex h-12 shrink-0 items-center justify-center gap-2 rounded-xl border border-cyan-200 bg-white px-4 text-sm font-bold text-cyan-800 transition hover:bg-cyan-50"
            >
              <.icon name="hero-microphone" class="size-4" /> Speak
            </button>
            <button
              id="preview-business-command"
              type="submit"
              class="inline-flex h-12 shrink-0 items-center justify-center rounded-xl bg-cyan-700 px-5 text-sm font-bold text-white transition hover:bg-cyan-800"
            >
              Preview action
            </button>
          </div>
        </.form>

        <div
          :if={@pending_business_command}
          id="business-command-preview"
          class="mt-4 rounded-2xl border border-cyan-200 bg-white p-5 shadow-sm"
        >
          <p class="text-xs font-bold uppercase tracking-wide text-cyan-700">Confirmation required</p>
          <p class="mt-2 text-sm font-semibold text-slate-900">{@pending_business_command.preview}</p>
          <p class="mt-1 text-xs text-slate-500">
            Original instruction: “{@pending_business_command.original}”
          </p>
          <div class="mt-4 flex gap-2">
            <button
              id="confirm-business-command"
              phx-click="confirm_business_command"
              class="rounded-xl bg-cyan-700 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-cyan-800"
            >
              Confirm
            </button>
            <button
              id="cancel-business-command"
              phx-click="cancel_business_command"
              class="rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-bold text-slate-600 transition hover:bg-slate-50"
            >
              Cancel
            </button>
          </div>
        </div>

        <div class="my-6 flex items-center gap-3">
          <span class="h-px flex-1 bg-cyan-100"></span>
          <span class="text-[10px] font-bold uppercase tracking-wider text-cyan-600">
            or launch a complete starter
          </span>
          <span class="h-px flex-1 bg-cyan-100"></span>
        </div>
        <.form
          for={@starter_business_form}
          id="starter-business-form"
          phx-submit="build_starter_business"
          class="grid gap-3 sm:grid-cols-[1fr_180px_auto] sm:items-end"
        >
          <.input
            field={@starter_business_form[:niche]}
            type="text"
            label="Your niche or audience"
            placeholder="Women’s fashion, school essentials…"
            required
          />
          <.input
            field={@starter_business_form[:count]}
            type="select"
            label="Starter size"
            options={[{"3 products", "3"}, {"5 products", "5"}]}
          />
          <button
            id="build-starter-business"
            type="submit"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-slate-950 px-5 text-sm font-bold text-white transition hover:-translate-y-0.5 hover:bg-cyan-800"
          >
            <.icon name="hero-building-storefront" class="size-4" /> Build starter business
          </button>
        </.form>
        <p class="mt-2 text-xs text-slate-500">
          This adds eligible products to your existing branded storefront, creates tracked links,
          and prepares content drafts for review. It never publishes claims without your approval.
        </p>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".VoiceCommand">
          export default {
            mounted() {
              const button = this.el.querySelector("#voice-command-button")
              const input = this.el.querySelector("input[name='business_command[instruction]']")
              const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition

              button.addEventListener("click", () => {
                if (!Recognition) {
                  input.focus()
                  input.placeholder = "Voice input is not supported by this browser. Type your instruction."
                  return
                }

                const recognition = new Recognition()
                recognition.lang = document.documentElement.lang || "en-GH"
                recognition.interimResults = false
                button.textContent = "Listening…"
                recognition.onresult = event => {
                  input.value = event.results[0][0].transcript
                  input.dispatchEvent(new Event("input", {bubbles: true}))
                }
                recognition.onend = () => { button.textContent = "Speak" }
                recognition.onerror = () => { button.textContent = "Try again" }
                recognition.start()
              })
            }
          }
        </script>
      </section>

      <section
        id="connection-invite-panel"
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7"
      >
        <div class="mb-5">
          <h2 class="text-lg font-semibold text-slate-900">Invite a store</h2>
          <p class="mt-1 text-sm text-slate-500">
            Enter the store name from its Makola address, for example <span class="font-medium">kente-kingdom</span>.
          </p>
        </div>

        <.form
          for={@form}
          id="supply-connection-form"
          phx-submit="request_connection"
          class="grid gap-4 md:grid-cols-[1fr_1fr_auto] md:items-end"
        >
          <.input
            field={@form[:partner_slug]}
            type="text"
            label="Store address"
            placeholder="store-name"
            required
          />
          <.input
            field={@form[:relationship]}
            type="select"
            label="What do you want to do?"
            options={[
              {"Sell their products", "resell"},
              {"Supply products to them", "supply"}
            ]}
          />
          <button
            id="send-connection-invite"
            type="submit"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-emerald-600 px-5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-emerald-700 hover:shadow-md"
          >
            <.icon name="hero-paper-airplane" class="size-4" /> Send invite
          </button>
        </.form>
      </section>

      <section aria-labelledby="connections-heading" class="space-y-4">
        <div class="flex items-end justify-between gap-4">
          <div>
            <h2 id="connections-heading" class="text-xl font-semibold text-slate-900">
              Your connections
            </h2>
            <p class="mt-1 text-sm text-slate-500">
              Both stores must agree before products can be shared.
            </p>
          </div>
          <span
            id="connection-count"
            class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
          >
            {@connection_count}
          </span>
        </div>

        <div id="supply-connections" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
          <div
            id="connections-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"
          >
            <.icon name="hero-link" class="mx-auto size-9 text-slate-300" />
            <p class="mt-3 text-sm font-semibold text-slate-700">No network connections yet</p>
            <p class="mt-1 text-xs text-slate-500">
              Invite a trusted store to start building your supplier network.
            </p>
          </div>

          <article
            :for={{dom_id, connection} <- @streams.connections}
            id={dom_id}
            class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-slate-300 hover:shadow-md"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex min-w-0 items-center gap-3">
                <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
                  <.icon name="hero-building-storefront" class="size-5" />
                </div>
                <div class="min-w-0">
                  <h3 class="truncate font-semibold text-slate-900">
                    {partner(connection, @current_store.id).name}
                  </h3>
                  <p class="truncate text-xs text-slate-500">
                    @{partner(connection, @current_store.id).slug}
                  </p>
                </div>
              </div>
              <span class={[
                "rounded-full px-2.5 py-1 text-[11px] font-semibold capitalize ring-1 ring-inset",
                status_classes(connection.status)
              ]}>
                {connection.status}
              </span>
            </div>

            <p class="mt-4 text-sm text-slate-600">
              {relationship_label(connection, @current_store.id)}
            </p>
            <p :if={connection.status_reason} class="mt-1 text-xs text-slate-400">
              {connection.status_reason}
            </p>

            <div class="mt-5 flex flex-wrap gap-2 border-t border-slate-100 pt-4">
              <%= if incoming?(connection, @current_store.id) do %>
                <button
                  id={"approve-connection-#{connection.id}"}
                  phx-click="approve_connection"
                  phx-value-id={connection.id}
                  class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
                >
                  Accept
                </button>
                <button
                  id={"reject-connection-#{connection.id}"}
                  phx-click="reject_connection"
                  phx-value-id={connection.id}
                  class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600 transition hover:bg-slate-50"
                >
                  Decline
                </button>
              <% end %>
              <button
                :if={connection.status == :active}
                id={"suspend-connection-#{connection.id}"}
                phx-click="suspend_connection"
                phx-value-id={connection.id}
                class="rounded-lg border border-amber-200 px-3 py-2 text-xs font-semibold text-amber-700 transition hover:bg-amber-50"
              >
                Pause
              </button>
              <button
                :if={connection.status == :suspended}
                id={"reactivate-connection-#{connection.id}"}
                phx-click="reactivate_connection"
                phx-value-id={connection.id}
                class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
              >
                Reactivate
              </button>
              <button
                :if={connection.status in [:pending, :active, :suspended]}
                id={"terminate-connection-#{connection.id}"}
                phx-click="terminate_connection"
                phx-value-id={connection.id}
                class="ml-auto rounded-lg px-3 py-2 text-xs font-semibold text-rose-600 transition hover:bg-rose-50"
              >
                End connection
              </button>
            </div>
          </article>
        </div>
      </section>

      <section id="earn-catalog" aria-labelledby="earn-catalog-heading" class="space-y-5">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-600">
              Earn catalog
            </span>
            <h2
              id="earn-catalog-heading"
              class="mt-1 text-2xl font-bold tracking-tight text-slate-950"
            >
              Products you can sell today
            </h2>
            <p class="mt-1 max-w-2xl text-sm text-slate-500">
              No stock payment upfront. Add a partner product, share your storefront, and keep the displayed earning when it sells.
            </p>
          </div>
          <span
            id="available-offer-count"
            class="w-fit rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-700 ring-1 ring-emerald-600/15"
          >
            {@offer_count} available
          </span>
        </div>

        <p class="text-xs text-slate-500 mb-3">
          Browsing has moved:
          <.link navigate="/admin/supply/catalog" class="text-emerald-700 font-medium">
            Supplier Catalog
          </.link>
          · manage your own offers in
          <.link navigate="/admin/supply/offers" class="text-emerald-700 font-medium">
            My Offers
          </.link>
        </p>

        <div id="earn-offers" phx-update="stream" class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          <div
            id="offers-empty"
            class="hidden only:block rounded-3xl border border-dashed border-slate-300 bg-slate-50 p-10 text-center md:col-span-2 xl:col-span-3"
          >
            <.icon name="hero-shopping-bag" class="mx-auto size-9 text-slate-300" />
            <p class="mt-3 text-sm font-semibold text-slate-700">No new products available</p>
            <p class="mt-1 text-xs text-slate-500">
              Connect with a supplier or check back when partners publish new offers.
            </p>
          </div>

          <article
            :for={{dom_id, offer} <- @streams.offers}
            id={dom_id}
            class="group overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm transition duration-200 hover:-translate-y-1 hover:border-emerald-200 hover:shadow-xl hover:shadow-emerald-950/5"
          >
            <div class="relative aspect-[16/10] overflow-hidden bg-gradient-to-br from-emerald-50 to-slate-100">
              <img
                :if={lead_image(offer)}
                src={lead_image(offer).url}
                alt={lead_image(offer).alt_text || offer.source_product.title}
                class="size-full object-cover transition duration-500 group-hover:scale-[1.03]"
                loading="lazy"
              />
              <div
                :if={!lead_image(offer)}
                class="flex size-full items-center justify-center text-emerald-200"
              >
                <.icon name="hero-photo" class="size-12" />
              </div>
              <span class="absolute left-3 top-3 rounded-full bg-slate-950/85 px-3 py-1 text-[11px] font-bold text-white backdrop-blur">
                No upfront stock
              </span>
            </div>
            <div class="p-5">
              <p class="text-xs font-medium text-slate-400">{offer.wholesaler_store.name}</p>
              <h3 class="mt-1 line-clamp-2 text-lg font-bold text-slate-900">
                {offer.source_product.title}
              </h3>
              <div class="mt-4 grid grid-cols-2 gap-3 rounded-2xl bg-slate-50 p-3">
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wide text-slate-400">Sell for</p>
                  <p class="mt-1 text-sm font-bold text-slate-800">{retail_range(offer)}</p>
                </div>
                <div class="border-l border-slate-200 pl-3">
                  <p class="text-[10px] font-bold uppercase tracking-wide text-emerald-600">
                    You earn
                  </p>
                  <p class="mt-1 text-sm font-bold text-emerald-700">{earning_range(offer)}</p>
                </div>
              </div>
              <%!-- What the SUPPLIER will take back from you. Your shoppers are
                   quoted your own returns policy, not this — you are the seller
                   of record — so any promise you make beyond this line is one
                   you absorb yourself. Better to see it before you import. --%>
              <div class="mt-3 rounded-2xl border border-slate-100 bg-white px-3 py-2">
                <p class="text-[10px] font-bold uppercase tracking-wide text-slate-400">
                  Supplier backs
                </p>
                <p class={[
                  "mt-1 text-xs font-semibold",
                  if(supplier_terms(offer) == [], do: "text-amber-700", else: "text-slate-700")
                ]}>
                  {supplier_backing_line(offer)}
                </p>
                <p :if={offer.return_terms} class="mt-1 text-[11px] leading-snug text-slate-500">
                  {offer.return_terms}
                </p>
              </div>
              <button
                id={"import-offer-#{offer.id}"}
                phx-click="import_offer"
                phx-value-id={offer.id}
                class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-3 text-sm font-bold text-white shadow-sm transition hover:bg-emerald-700 active:scale-[0.98]"
              >
                <.icon name="hero-plus" class="size-4" /> Add to my store
              </button>
            </div>
          </article>
        </div>
      </section>

      <section id="earned-listings" aria-labelledby="earned-listings-heading" class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 id="earned-listings-heading" class="text-xl font-semibold text-slate-900">
              Added from partners
            </h2>
            <p class="mt-1 text-sm text-slate-500">
              These products behave like the rest of your catalog and fulfill through their supplier.
            </p>
          </div>
          <span
            id="listing-count"
            class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
          >
            {@listing_count}
          </span>
        </div>
        <div id="reseller-listings" phx-update="stream" class="grid gap-3 sm:grid-cols-2">
          <div
            id="listings-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center sm:col-span-2"
          >
            <p class="text-sm font-semibold text-slate-700">
              You have not added a partner product yet.
            </p>
          </div>
          <article
            :for={{dom_id, listing} <- @streams.listings}
            id={dom_id}
            class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
              <.icon name="hero-check" class="size-5" />
            </div>
            <div class="min-w-0 flex-1">
              <h3 class="truncate text-sm font-semibold text-slate-900">
                {listing.reseller_product.title}
              </h3>
              <p class="mt-0.5 text-xs capitalize text-slate-500">
                {listing.status} · Synced from partner
              </p>
            </div>
            <button
              id={"create-content-draft-#{listing.id}"}
              phx-click="create_content_draft"
              phx-value-id={listing.id}
              phx-value-locale="en-GH"
              class="rounded-lg border border-violet-200 px-3 py-2 text-xs font-bold text-violet-700 transition hover:bg-violet-50"
            >
              Content
            </button>
            <button
              id={"create-twi-content-draft-#{listing.id}"}
              phx-click="create_content_draft"
              phx-value-id={listing.id}
              phx-value-locale="tw-GH"
              class="rounded-lg border border-amber-200 px-3 py-2 text-xs font-bold text-amber-700 transition hover:bg-amber-50"
            >
              Twi
            </button>
            <button
              id={"create-sales-kit-#{listing.id}"}
              phx-click="create_sales_kit"
              phx-value-id={listing.id}
              class="rounded-lg border border-emerald-200 px-3 py-2 text-xs font-bold text-emerald-700 transition hover:bg-emerald-50"
            >
              Sales kit
            </button>
            <.link
              navigate={~p"/admin/products/#{listing.reseller_product_id}/edit"}
              class="rounded-lg p-2 text-slate-400 transition hover:bg-slate-50 hover:text-slate-700"
              aria-label={"Edit #{listing.reseller_product.title}"}
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </.link>
          </article>
        </div>
      </section>

      <section id="earn-content-studio" aria-labelledby="content-studio-heading" class="space-y-4">
        <div class="flex items-end justify-between gap-4">
          <div>
            <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-600">
              Content Studio
            </span>
            <h2 id="content-studio-heading" class="mt-1 text-xl font-bold text-slate-950">
              Fact-grounded drafts you control
            </h2>
            <p class="mt-1 max-w-2xl text-sm text-slate-500">
              Every draft is constrained to the supplier's approved facts. Nothing is published until you review and approve it.
            </p>
          </div>
          <span
            id="content-draft-count"
            class="rounded-full bg-violet-50 px-3 py-1 text-xs font-bold text-violet-700"
          >
            {@content_draft_count}
          </span>
        </div>

        <div id="content-drafts" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
          <div
            id="content-drafts-empty"
            class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center lg:col-span-2"
          >
            <p class="text-sm font-semibold text-slate-700">
              Create a draft from one of your partner products.
            </p>
          </div>
          <article
            :for={{dom_id, draft} <- @streams.content_drafts}
            id={dom_id}
            class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs font-bold uppercase tracking-wide text-violet-600">
                  {draft.locale} · {draft.generator}
                </p>
                <h3 class="mt-1 font-bold text-slate-900">{draft.source_facts["product_title"]}</h3>
              </div>
              <span class={[
                "rounded-full px-2.5 py-1 text-[11px] font-bold capitalize",
                content_status_classes(draft.status)
              ]}>
                {draft.status}
              </span>
            </div>
            <div class="mt-4 space-y-3">
              <img
                :if={draft.content["social_card_data_uri"]}
                id={"content-social-card-#{draft.id}"}
                src={draft.content["social_card_data_uri"]}
                alt={"Sales card for #{draft.source_facts["product_title"]}"}
                class="aspect-square w-full rounded-xl border border-slate-200 object-cover"
              />
              <div class="rounded-xl bg-emerald-50 p-3">
                <p class="text-[10px] font-bold uppercase text-emerald-700">WhatsApp</p>
                <p class="mt-1 text-sm leading-5 text-slate-700">{draft.content["whatsapp"]}</p>
              </div>
              <div class="rounded-xl bg-blue-50 p-3">
                <p class="text-[10px] font-bold uppercase text-blue-700">Facebook</p>
                <p class="mt-1 text-sm leading-5 text-slate-700">{draft.content["facebook"]}</p>
              </div>
              <details class="rounded-xl border border-slate-200 p-3">
                <summary class="cursor-pointer text-xs font-bold text-slate-700">
                  View source facts
                </summary>
                <dl class="mt-3 space-y-2 text-xs">
                  <div>
                    <dt class="text-slate-400">Supplier description</dt>
                    <dd class="text-slate-700">{draft.source_facts["supplier_description"]}</dd>
                  </div>
                  <div>
                    <dt class="text-slate-400">Return terms</dt>
                    <dd class="text-slate-700">{draft.source_facts["return_terms"]}</dd>
                  </div>
                </dl>
              </details>
            </div>
            <div :if={draft.status == :draft} class="mt-4 flex gap-2 border-t border-slate-100 pt-4">
              <button
                id={"approve-content-draft-#{draft.id}"}
                phx-click="approve_content_draft"
                phx-value-id={draft.id}
                class="rounded-xl bg-emerald-600 px-4 py-2 text-xs font-bold text-white transition hover:bg-emerald-700"
              >
                Approve
              </button>
              <button
                id={"reject-content-draft-#{draft.id}"}
                phx-click="reject_content_draft"
                phx-value-id={draft.id}
                class="rounded-xl border border-rose-200 px-4 py-2 text-xs font-bold text-rose-700 transition hover:bg-rose-50"
              >
                Reject
              </button>
            </div>
          </article>
        </div>
      </section>

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
                  {share.click_count} clicks · {share.order_count} orders
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
              {@inbound_count} orders
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
                {length(fulfillment.line_items)} item types
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
    </div>
    """
  end
end
