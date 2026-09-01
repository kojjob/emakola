defmodule EmakolaWeb.Admin.SupplyNetworkLive.Data do
  @moduledoc "Loads and aggregates actor-scoped data for the supply-network LiveView."

  require Ash.Query

  import Phoenix.Component, only: [assign: 3]

  alias Emakola.Suppliers.{
    CommercePassports,
    ContentStudio,
    Franchises,
    GoalProgress,
    GroupBuys,
    HustlePlanner,
    InboundFulfillment,
    IncomeGoals,
    InventoryReservations,
    ListingImporter,
    Network,
    OpportunityRadar,
    OpportunitySignals,
    Offers,
    RadarEvaluation,
    SalesSharing,
    SalesTeams
  }

  alias EmakolaWeb.Admin.SupplyNetworkLive.{Inputs, Presentation}

  # RequireActiveStore lets a merchant who has not created a store reach the
  # admin ("still onboarding … passes through untouched"), so current_store can
  # be nil here. Every loader below dereferences store.id; the defaults from
  # Inputs.default_assigns/0 already describe an empty network, so the page
  # renders its own empty states rather than raising.
  def load_all(%{assigns: %{current_store: nil}} = socket) do
    # Every stream the template renders must still exist, empty — a template
    # reading @streams.connections raises just as loudly as a nil store did.
    ~w(available_franchise_packages commerce_signals connections content_drafts
       eligible_inventory_policies group_buys inbound_fulfillments
       inventory_reservations listings offers opportunity_radar
       owned_franchise_packages owned_inventory_policies sales_shares
       sales_team_invitations sales_teams supplier_demand_alerts)a
    |> Enum.reduce(socket, &Phoenix.LiveView.stream(&2, &1, [], reset: true))
    |> assign(:active_connection, nil)
    |> assign(:collaboration_owned_offers, [])
    |> assign(:radar_offers, [])
  end

  def load_all(socket) do
    socket
    |> load_connections()
    |> load_earn_catalog()
    |> load_inbound_fulfillments()
    |> load_sales_journey()
    |> load_income_goal()
    |> load_content_drafts()
    |> load_opportunity_radar()
    |> load_collaborative_commerce()
    |> load_commerce_passport()
    |> load_inventory_eligibility()
  end

  def load_connections(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    connections =
      case Network.list_for_store(actor, store.id) do
        {:ok, rows} -> Ash.load!(rows, [:wholesaler_store, :reseller_store], authorize?: false)
        _error -> []
      end

    socket
    |> assign(:connections, connections)
    |> assign(:connection_count, length(connections))
    |> assign(:active_connection?, Enum.any?(connections, &(&1.status == :active)))
    |> Phoenix.LiveView.stream(:connections, connections, reset: true)
  end

  def load_earn_catalog(socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    offers = result_rows(Offers.list_available(actor, store.id))
    listings = result_rows(ListingImporter.list(actor, store.id, preload: :source_variants))
    imported_offer_ids = MapSet.new(listings, & &1.offer_id)
    available = Enum.reject(offers, &MapSet.member?(imported_offer_ids, &1.id))

    socket
    |> assign(:offer_count, length(available))
    |> assign(:listing_count, length(listings))
    |> assign(:listing_preview, Enum.take(listings, 3))
    |> assign(
      :low_stock_listing_count,
      Enum.count(listings, &(Presentation.listing_stock_status(&1) == :low))
    )
    |> assign(:radar_offers, offers)
    |> assign(:hustle_opportunities, Enum.map(offers, &hustle_opportunity/1))
    |> assign(:hustle_listings, listings)
    |> Phoenix.LiveView.stream(:offers, available, reset: true)
    |> Phoenix.LiveView.stream(:listings, listings, reset: true)
  end

  def load_inbound_fulfillments(socket) do
    fulfillments =
      socket.assigns.current_merchant
      |> InboundFulfillment.list(socket.assigns.current_store.id)
      |> result_rows()

    socket
    |> assign(:inbound_count, length(fulfillments))
    |> assign(:inbound_preview, Enum.take(fulfillments, 2))
    |> Phoenix.LiveView.stream(:inbound_fulfillments, fulfillments, reset: true)
  end

  def load_sales_journey(socket) do
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
    |> assign(:sales_preview, Enum.take(shares, 2))
    |> assign(:hustle_shares, shares)
    |> assign(:partner_stats, partner_stats(socket.assigns.hustle_listings, shares))
    |> assign(:first_money, first_money)
    |> Phoenix.LiveView.stream(:sales_shares, shares, reset: true)
  end

  # Per partner store: how many of its products this store lists, and how
  # many orders those listings' sales kits brought. Keyed by the wholesaler
  # store id, so the hub can put the numbers on each connection row.
  defp partner_stats(listings, shares) do
    orders_by_product =
      Enum.reduce(shares, %{}, fn share, acc ->
        Map.update(acc, share.product_id, share.order_count, &(&1 + share.order_count))
      end)

    Enum.reduce(listings, %{}, fn listing, acc ->
      case listing do
        %{offer: %{wholesaler_store_id: partner_id}} when is_binary(partner_id) ->
          orders = Map.get(orders_by_product, listing.reseller_product_id, 0)

          Map.update(acc, partner_id, %{products: 1, orders: orders}, fn row ->
            %{products: row.products + 1, orders: row.orders + orders}
          end)

        _listing ->
          acc
      end
    end)
  end

  def load_income_goal(socket) do
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

  def load_content_drafts(socket) do
    drafts =
      socket.assigns.current_merchant
      |> ContentStudio.list(socket.assigns.current_store.id)
      |> result_rows()

    socket
    |> assign(:content_draft_count, length(drafts))
    |> Phoenix.LiveView.stream(:content_drafts, drafts, reset: true)
  end

  def load_opportunity_radar(socket) do
    events = OpportunitySignals.recent() |> result_rows()

    radar =
      OpportunityRadar.build(
        socket.assigns[:radar_offers] || [],
        socket.assigns.hustle_listings,
        socket.assigns.hustle_shares,
        events,
        socket.assigns.current_store.id
      )
      |> RadarEvaluation.rank(socket.assigns.current_store.id)

    OpportunitySignals.emit_supplier_alerts(radar)
    alerts = OpportunitySignals.supplier_alerts(socket.assigns.current_store.id) |> result_rows()

    socket
    |> assign(:opportunity_radar_count, length(radar))
    |> assign(:supplier_demand_alert_count, length(alerts))
    |> Phoenix.LiveView.stream(:opportunity_radar, radar, reset: true)
    |> Phoenix.LiveView.stream(:supplier_demand_alerts, alerts, reset: true)
  end

  def load_collaborative_commerce(socket) do
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
    |> Phoenix.LiveView.stream(:group_buys, campaigns, reset: true)
    |> Phoenix.LiveView.stream(:sales_teams, teams, reset: true)
    |> Phoenix.LiveView.stream(:sales_team_invitations, invitations, reset: true)
    |> Phoenix.LiveView.stream(:owned_franchise_packages, owned_packages, reset: true)
    |> Phoenix.LiveView.stream(:available_franchise_packages, available_packages, reset: true)
  end

  def load_commerce_passport(socket) do
    case CommercePassports.inspect(
           socket.assigns.current_merchant,
           socket.assigns.current_store.id
         ) do
      {:ok, passport} -> assign_passport(socket, passport)
      _error -> socket |> assign(:commerce_passport, nil) |> stream(:commerce_signals, [])
    end
  end

  def load_inventory_eligibility(socket) do
    actor = socket.assigns.current_merchant
    store_id = socket.assigns.current_store.id
    owned = InventoryReservations.owned_policies(actor, store_id) |> result_rows()
    eligible = InventoryReservations.eligible_policies(actor, store_id) |> result_rows()
    reservations = InventoryReservations.list(actor, store_id) |> result_rows()

    forms = Map.new(eligible, &{&1.id, Inputs.inventory_reservation_form(&1.id)})

    socket
    |> assign(:inventory_reservation_forms, forms)
    |> assign(:reservation_count, length(reservations))
    |> Phoenix.LiveView.stream(:owned_inventory_policies, owned, reset: true)
    |> Phoenix.LiveView.stream(:eligible_inventory_policies, eligible, reset: true)
    |> Phoenix.LiveView.stream(:inventory_reservations, reservations, reset: true)
  end

  def assign_passport(socket, passport) do
    signals = Enum.reject(passport.signals, &(&1.status == :expired))
    forms = Map.new(signals, &{&1.id, Inputs.passport_appeal_form(&1.id)})

    socket
    |> assign(:commerce_passport, passport)
    |> assign(:passport_appeal_forms, forms)
    |> Phoenix.LiveView.stream(:commerce_signals, signals, reset: true)
  end

  def merchant_by_email(email) do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(email == ^String.trim(email))
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{} = merchant} -> {:ok, merchant}
      _error -> {:error, :merchant_not_found}
    end
  end

  defp stream(socket, name, rows) do
    Phoenix.LiveView.stream(socket, name, rows, reset: true)
  end

  defp result_rows({:ok, rows}), do: rows
  defp result_rows(_error), do: []

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
end
