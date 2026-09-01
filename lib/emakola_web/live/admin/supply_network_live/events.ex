defmodule EmakolaWeb.Admin.SupplyNetworkLive.Events do
  @moduledoc """
  Every event the supply-network pages handle, shared by the Partners hub
  and the tools page. Each clause reads and writes socket assigns only, so
  either page can host it. Moved verbatim from SupplyNetworkLive.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Emakola.Suppliers.{
    BusinessCommand,
    CommercePassports,
    ContentStudio,
    Franchises,
    GroupBuys,
    InboundFulfillment,
    IncomeGoals,
    InventoryReservations,
    ListingImporter,
    Network,
    Offers,
    SalesSharing,
    SalesTeams,
    StarterBusiness
  }

  alias EmakolaWeb.Admin.SupplyNetworkLive.{
    Commands,
    Data,
    Inputs,
    Presentation
  }

  def handle_event("request_connection", %{"connection" => params}, socket) do
    store = socket.assigns.current_store
    actor = socket.assigns.current_merchant
    slug = params |> Map.get("partner_slug", "") |> String.trim()

    case Emakola.Stores.get_store_by_slug(slug, authorize?: false) do
      {:ok, partner} ->
        attrs = Inputs.connection_attrs(store.id, partner.id, params["relationship"])

        case Network.request(actor, attrs) do
          {:ok, _connection} ->
            {:noreply,
             socket
             |> assign(:form, Inputs.connection_form())
             |> Data.load_connections()
             |> put_flash(:info, "Invitation sent to #{partner.name}.")}

          {:error, :connection_exists} ->
            {:noreply, put_flash(socket, :error, "A connection with this store already exists.")}

          {:error, :stores_must_differ} ->
            {:noreply, put_flash(socket, :error, "Choose another store, not your own.")}

          {:error, :invite_rate_limited} ->
            {:noreply,
             put_flash(socket, :error, "Invite limit reached — please try again later.")}

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
       |> Data.load_earn_catalog()
       |> Data.load_sales_journey()
       |> Data.load_income_goal()
       |> Data.load_collaborative_commerce()
       |> put_flash(:info, "Product added to your store. Its images are being prepared.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "This offer is no longer available.")}

      {:error, :listing_exists} ->
        {:noreply,
         socket
         |> Data.load_earn_catalog()
         |> Data.load_sales_journey()
         |> Data.load_income_goal()
         |> Data.load_collaborative_commerce()
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
       |> Data.load_sales_journey()
       |> Data.load_income_goal()
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
         |> Data.load_content_drafts()
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
        {:noreply, socket |> Data.load_content_drafts() |> put_flash(:info, "Content approved.")}

      {:error, :source_facts_changed} ->
        {:noreply,
         socket
         |> Data.load_content_drafts()
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
        {:noreply, socket |> Data.load_content_drafts() |> put_flash(:info, "Draft rejected.")}

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
    case Commands.execute(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           socket.assigns.hustle_listings,
           socket.assigns.pending_business_command
         ) do
      {:ok, message} ->
        {:noreply,
         socket
         |> assign(
           pending_business_command: nil,
           business_command_form: Inputs.business_command_form()
         )
         |> Data.load_earn_catalog()
         |> Data.load_sales_journey()
         |> Data.load_income_goal()
         |> Data.load_content_drafts()
         |> Data.load_collaborative_commerce()
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
         |> assign(:starter_business_form, Inputs.starter_business_form())
         |> Data.load_earn_catalog()
         |> Data.load_sales_journey()
         |> Data.load_income_goal()
         |> Data.load_content_drafts()
         |> Data.load_collaborative_commerce()
         |> put_flash(
           :info,
           "Starter business ready: #{Emakola.Plural.count(result.imported, "product")}, tracked links, and reviewable content drafts."
         )}

      {:error, :no_matching_offers} ->
        {:noreply,
         put_flash(socket, :error, "Connect with a supplier that has eligible products first.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The starter business could not be created.")}
    end
  end

  def handle_event("refresh_opportunity_radar", _params, socket) do
    {:noreply, Data.load_opportunity_radar(socket)}
  end

  def handle_event("create_group_buy", %{"group_buy" => params}, socket) do
    with %{} = mapping <-
           Inputs.find_listing_mapping(
             socket.assigns.hustle_listings,
             params["listing_variant_id"]
           ),
         attrs <- Inputs.group_buy_attrs(params, mapping),
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
       |> assign(:group_buy_form, Inputs.group_buy_form())
       |> Data.load_collaborative_commerce()
       |> put_flash(:info, "Group buy opened with a locked price and refund deadline.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "Choose an imported product variant.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.group_buy_error(reason))}
    end
  end

  def handle_event("create_sales_team", %{"sales_team" => params}, socket) do
    with {:ok, collaborator} <- Data.merchant_by_email(params["collaborator_email"]),
         {:ok, owner_bps} <- Inputs.percent_bps(params["owner_percent"]),
         {:ok, collaborator_bps} <- Inputs.percent_bps(params["collaborator_percent"]),
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
       |> assign(:sales_team_form, Inputs.sales_team_form())
       |> Data.load_collaborative_commerce()
       |> put_flash(
         :info,
         "Team invitation created. Earnings stay inactive until the collaborator consents."
       )}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.sales_team_error(reason))}
    end
  end

  def handle_event("accept_sales_team", %{"id" => member_id}, socket) do
    case SalesTeams.accept(socket.assigns.current_merchant, member_id) do
      {:ok, _member} ->
        {:noreply,
         socket
         |> Data.load_collaborative_commerce()
         |> put_flash(:info, "You accepted the declared role and split.")}

      _error ->
        {:noreply, put_flash(socket, :error, "The invitation could not be accepted.")}
    end
  end

  def handle_event("create_franchise_package", %{"franchise" => params}, socket) do
    attrs = Inputs.franchise_attrs(params)

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
       |> assign(:franchise_form, Inputs.franchise_form())
       |> Data.load_collaborative_commerce()
       |> put_flash(:info, "Micro-franchise package published to connected resellers.")}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.franchise_error(reason))}
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
         |> Data.load_collaborative_commerce()
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
         |> Data.load_collaborative_commerce()
         |> put_flash(:info, "Partner approved and package catalog activated.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.franchise_error(reason))}
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
         |> Data.assign_passport(passport)
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
         |> Data.load_commerce_passport()
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
         |> assign(:inventory_policy_form, Inputs.inventory_policy_form())
         |> Data.load_inventory_eligibility()
         |> put_flash(:info, "Transparent inventory eligibility published.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.inventory_error(reason))}
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
         |> Data.load_inventory_eligibility()
         |> put_flash(:info, "Inventory held until the displayed expiry time.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.inventory_error(reason))}
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
         |> Data.load_inventory_eligibility()
         |> put_flash(:info, "Unused inventory returned to the supplier.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Presentation.inventory_error(reason))}
    end
  end

  def handle_event("record_sales_share", %{"id" => share_id}, socket) do
    SalesSharing.record_share(
      socket.assigns.current_merchant,
      socket.assigns.current_store.id,
      share_id
    )

    {:noreply, socket |> Data.load_sales_journey() |> Data.load_income_goal()}
  end

  def handle_event("create_income_goal", %{"income_goal" => params}, socket) do
    attrs = Inputs.income_goal_attrs(params)

    case IncomeGoals.create(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id,
           attrs
         ) do
      {:ok, _goal} ->
        {:noreply,
         socket
         |> assign(:income_goal_form, Inputs.income_goal_form())
         |> Data.load_income_goal()
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
       shipping_form: Inputs.shipment_form()
     )
     |> Data.load_inbound_fulfillments()}
  end

  def handle_event("cancel_inbound_shipping", _params, socket) do
    {:noreply,
     socket |> assign(:shipping_fulfillment_id, nil) |> Data.load_inbound_fulfillments()}
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
         |> Data.load_inbound_fulfillments()
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
           delivery_form: Inputs.delivery_form()
         )
         |> Data.load_inbound_fulfillments()
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
       delivery_form: Inputs.delivery_form()
     )
     |> Data.load_inbound_fulfillments()}
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
         |> Data.load_inbound_fulfillments()
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
       |> Data.load_connections()
       |> Data.load_earn_catalog()
       |> Data.load_sales_journey()
       |> put_flash(:info, success_message)}
    else
      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You cannot perform that action.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The connection could not be updated.")}
    end
  end
end
