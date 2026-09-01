defmodule EmakolaWeb.Admin.SupplyNetworkLiveTest do
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.{Network, Offers}

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    partner = create_store!(name: "Accra Wholesale", slug: "accra-wholesale")
    partner_merchant = create_merchant!()
    create_store_membership!(partner_merchant, partner, :owner)

    %{
      conn: conn,
      merchant: merchant,
      store: store,
      partner: partner,
      partner_merchant: partner_merchant
    }
  end

  test "a merchant with no store yet gets the page, not a 500", %{conn: _conn} do
    # RequireActiveStore deliberately lets a merchant who has not created a
    # store through to the admin ("still onboarding … passes through
    # untouched"), so every store-backed loader must tolerate a nil store.
    # On production this raised (KeyError) key :id not found in: nil from
    # Data.load_connections/1 and returned "Something broke." — 2026-08-24.
    merchant = create_merchant!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    # build_conn/0 here is ConnCase's apex-host version — Phoenix's own
    # defaults to www.example.com, which the router sends to the storefront.
    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")

    assert has_element?(view, "#supply-network-page")
    assert has_element?(view, "#connection-count", "0")
  end

  test "renders an empty connection inbox with a stable invite form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#supply-network-tools")
    assert has_element?(view, "#supply-connection-form")
    assert has_element?(view, "#connections-empty")
    assert has_element?(view, "#connection-count", "0")
    assert has_element?(view, "#collaborative-commerce")
    assert has_element?(view, "#group-buy-form")
    assert has_element?(view, "#sales-team-form")
    assert has_element?(view, "#franchise-package-form")
    assert has_element?(view, "#commerce-passport")
    assert has_element?(view, "#commerce-signals article")
    assert has_element?(view, "#inventory-eligibility")
    assert has_element?(view, "#inventory-policy-form")
  end

  test "eligible reseller sees the reason, reserves stock, and releases unused units", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    offer = Ash.load!(offer, :offer_variants, authorize?: false)
    terms = List.first(offer.offer_variants)

    {:ok, policy} =
      Emakola.Suppliers.InventoryReservations.create_policy(
        ctx.partner_merchant,
        ctx.partner.id,
        terms.id,
        %{minimum_tier: :starter, max_quantity_per_reseller: 4, reservation_hours: 48}
      )

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
    assert has_element?(view, "#eligible-inventory-policies article", policy.reason_code)
    assert has_element?(view, "#eligible-inventory-policies article", "Requires starter+")

    view
    |> form("#reserve-inventory-form-#{policy.id}", inventory_reservation: %{quantity: "2"})
    |> render_submit()

    assert has_element?(view, "#inventory-reservations article", "2 of 2 held")

    {:ok, [reservation]} =
      Emakola.Suppliers.InventoryReservations.list(ctx.merchant, ctx.store.id)

    view |> element("#release-inventory-#{reservation.id}") |> render_click()
    assert has_element?(view, "#inventory-reservations article", "released")
  end

  test "merchant inspects, refreshes, and appeals passport evidence", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
    assert has_element?(view, "#passport-score")
    assert has_element?(view, "#passport-tier", "starter")
    assert has_element?(view, "#commerce-signals article", "Evidence:")
    assert has_element?(view, "#commerce-signals article", "Expires")

    view |> element("#refresh-commerce-passport") |> render_click()
    assert has_element?(view, "#commerce-signals article")

    {:ok, passport} =
      Emakola.Suppliers.CommercePassports.inspect(ctx.merchant, ctx.store.id)

    signal = Enum.find(passport.signals, &(&1.status == :active))

    view
    |> form("#passport-appeal-form-#{signal.id}",
      appeal: %{reason: "A completed delivery is missing from this evidence."}
    )
    |> render_submit()

    assert has_element?(view, "#commerce-signals article", "Appeal open")

    assert Ash.get!(Emakola.Suppliers.ReputationSignal, signal.id, authorize?: false).status ==
             :appealed
  end

  test "requests a reseller connection by partner store slug", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> form("#supply-connection-form",
      connection: %{partner_slug: ctx.partner.slug, relationship: "resell"}
    )
    |> render_submit()

    assert has_element?(view, "#connection-count", "1")
    assert has_element?(view, "#supply-connections article", ctx.partner.name)

    assert {:ok, [connection]} = Network.list_for_store(ctx.merchant, ctx.store.id)
    assert connection.wholesaler_store_id == ctx.partner.id
    assert connection.reseller_store_id == ctx.store.id
    assert connection.requested_by_store_id == ctx.store.id
    assert connection.status == :pending
  end

  test "throttled invite shows a rate-limit flash instead of sending", ctx do
    for _ <- 1..3 do
      Emakola.RateLimit.check_rate("supply_invite:burst:#{ctx.store.id}", 3, 60_000)
    end

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> form("#supply-connection-form",
      connection: %{partner_slug: ctx.partner.slug, relationship: "resell"}
    )
    |> render_submit()

    assert render(view) =~ "Invite limit reached"
  end

  test "shows a useful error for an unknown store", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network/tools")

    html =
      view
      |> form("#supply-connection-form",
        connection: %{partner_slug: "does-not-exist", relationship: "resell"}
      )
      |> render_submit()

    assert html =~ "No store was found"
    assert has_element?(view, "#connection-count", "0")
  end

  test "counterparty accepts an incoming invitation", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
    assert has_element?(view, "#approve-connection-#{pending.id}")

    view
    |> element("#approve-connection-#{pending.id}")
    |> render_click()

    assert has_element?(view, "#supply-connections article", "active")
    refute has_element?(view, "#approve-connection-#{pending.id}")

    assert {:ok, updated} = Network.get(ctx.merchant, pending.id)
    assert updated.status == :active
  end

  test "active connection can be paused and reactivated", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, active} = Network.approve(ctx.merchant, pending)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> element("#suspend-connection-#{active.id}")
    |> render_click()

    assert has_element?(view, "#reactivate-connection-#{active.id}")

    view
    |> element("#reactivate-connection-#{active.id}")
    |> render_click()

    assert has_element?(view, "#suspend-connection-#{active.id}")
  end

  test "active connection can be ended", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, active} = Network.approve(ctx.merchant, pending)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> element("#terminate-connection-#{active.id}")
    |> render_click()

    refute has_element?(view, "#terminate-connection-#{active.id}")
    assert has_element?(view, "#supply-connections article", "terminated")
  end

  test "shows published partner offers with clear earnings", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#earn-catalog")
    assert has_element?(view, "#available-offer-count", "1 available")
    assert has_element?(view, "#earn-offers article", "Partner Kente Bag")
    assert has_element?(view, "#earn-offers article", "GH₵15.00")
    assert has_element?(view, "#import-offer-#{offer.id}")
    assert has_element?(view, "#opportunity-radar")
    assert has_element?(view, "#opportunity-radar-items article", "Partner Kente Bag")
    assert has_element?(view, "#opportunity-radar-items article", "0 scarcity surcharge")
    assert has_element?(view, "#opportunity-radar-items article", "GH₵65.00")
  end

  # A merchant is the seller of record: whatever they promise a shopper, they
  # owe, whether or not their supplier stands behind it. So the offer card has
  # to say what the supplier actually backs BEFORE the merchant imports it.
  test "an offer card states what the supplier will honour back to the merchant", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)

    {:ok, _updated} =
      Offers.update_terms(ctx.partner_merchant, offer, %{
        returns_window_days: 7,
        warranty_months: 6,
        return_terms: "Faulty goods only, in original packaging."
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#earn-offers article", "7-day returns")
    assert has_element?(view, "#earn-offers article", "6-month warranty")
    assert has_element?(view, "#earn-offers article", "Faulty goods only, in original packaging.")
  end

  test "an offer backed by nothing says so, rather than staying quiet", ctx do
    create_partner_offer!(ctx)
    connect_partner!(ctx)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    # Silence here would read as "fine" — the merchant needs to know the gap is
    # theirs to fund before they promise a shopper 30 days.
    assert has_element?(view, "#earn-offers article", "Nothing stated")
  end

  test "creates an income goal and renders an explainable seven-day plan", ctx do
    create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#hustle-autopilot")
    assert has_element?(view, "#income-goal-form")

    view
    |> form("#income-goal-form",
      income_goal: %{
        target_amount: "300.00",
        timeframe_days: "30",
        daily_minutes: "45"
      }
    )
    |> render_submit()

    assert has_element?(view, "#active-income-goal")
    assert has_element?(view, "#income-goal-target", "GH₵300.00")
    assert has_element?(view, "#income-goal-required-sales", "23")
    assert has_element?(view, "#hustle-plan-actions li")
    assert has_element?(view, "#hustle-recommendations", "Supplier")
    assert has_element?(view, "#hustle-recommendations", "Customer")
    assert has_element?(view, "#hustle-recommendations", "Fee")
    assert has_element?(view, "#hustle-recommendations", "You earn")
    assert has_element?(view, "#hustle-recommendations", "GH₵13.50")
    assert has_element?(view, "#income-goal-disclaimer", "not guaranteed income")
    assert has_element?(view, "#income-goal-progress")
    assert has_element?(view, "#goal-net-earned", "GH₵0.00")
    assert has_element?(view, "#goal-publish-product")
    refute has_element?(view, "#income-goal-form")

    view |> element("#goal-publish-product") |> render_click()

    assert has_element?(view, "#goal-create-sales-kit")
  end

  test "adds an offer to the reseller catalog with one action", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> element("#import-offer-#{offer.id}")
    |> render_click()

    assert has_element?(view, "#available-offer-count", "0 available")
    assert has_element?(view, "#listing-count", "1")
    assert has_element?(view, "#reseller-listings article", "Partner Kente Bag")
    refute has_element?(view, "#import-offer-#{offer.id}")
  end

  test "wholesaler manages cross-store orders from the supplier inbox", ctx do
    fulfillment = create_inbound_fulfillment!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#supplier-inbox")
    assert has_element?(view, "#inbound-fulfillment-count", "1 orders")
    assert has_element?(view, "#inbound-fulfillments article", "Accra")

    view
    |> element("#prepare-shipment-#{fulfillment.id}")
    |> render_click()

    assert has_element?(view, "#ship-inbound-form-#{fulfillment.id}")

    view
    |> form("#ship-inbound-form-#{fulfillment.id}",
      shipment: %{tracking_number: "GH-INBOUND-1"}
    )
    |> render_submit()

    assert has_element?(view, "#send-delivery-code-#{fulfillment.id}")
    refute has_element?(view, "#prepare-shipment-#{fulfillment.id}")
  end

  test "creates a tracked Sales Kit and advances the First Money journey", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> element("#import-offer-#{offer.id}")
    |> render_click()

    {:ok, [listing]} =
      Emakola.Suppliers.ListingImporter.list(ctx.merchant, ctx.store.id)

    assert has_element?(view, "#first-money-journey")
    assert has_element?(view, "#create-sales-kit-#{listing.id}")

    view
    |> element("#create-sales-kit-#{listing.id}")
    |> render_click()

    assert has_element?(view, "#sales-shares article", "Partner Kente Bag")
    assert has_element?(view, "#sales-shares article", "WhatsApp")
    assert has_element?(view, "#sales-shares article", "Facebook")
    assert has_element?(view, "#sales-shares article", "Copy link")
    assert has_element?(view, "#first-money-step-shared")

    {:ok, shares} = Emakola.Suppliers.SalesSharing.list_for_store(ctx.merchant, ctx.store.id)
    copy_share = Enum.find(shares, &(&1.channel == :copy_link))

    view
    |> element("#copy-sales-link-#{copy_share.id}")
    |> render_click()

    updated = Ash.get!(Emakola.Suppliers.SalesShare, copy_share.id, authorize?: false)
    assert updated.share_count == 1
    assert has_element?(view, "#first-money-step-shared")
    assert has_element?(view, "#first-money-step-shared .bg-emerald-600")
  end

  test "creates and explicitly approves a supplier-fact-grounded content draft", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view |> element("#import-offer-#{offer.id}") |> render_click()
    {:ok, [listing]} = Emakola.Suppliers.ListingImporter.list(ctx.merchant, ctx.store.id)

    assert has_element?(view, "#earn-content-studio")
    view |> element("#create-content-draft-#{listing.id}") |> render_click()

    assert has_element?(view, "#content-draft-count", "1")
    assert has_element?(view, "#content-drafts article", "Partner Kente Bag")
    assert has_element?(view, "#content-drafts article", "GH₵65.00")

    {:ok, [draft]} = Emakola.Suppliers.ContentStudio.list(ctx.merchant, ctx.store.id)
    assert draft.status == :draft
    assert has_element?(view, "#content-social-card-#{draft.id}")
    assert has_element?(view, "#approve-content-draft-#{draft.id}")

    view |> element("#approve-content-draft-#{draft.id}") |> render_click()

    assert has_element?(view, "#content-drafts article", "approved")
    refute has_element?(view, "#approve-content-draft-#{draft.id}")
  end

  test "previews text or transcribed voice instructions before mutating the store", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    assert has_element?(view, "#business-in-a-box")
    assert has_element?(view, "#voice-command-control")

    view
    |> form("#business-command-form", business_command: %{instruction: "Add one product"})
    |> render_submit()

    assert has_element?(
             view,
             "#business-command-preview",
             "Add up to 1 top-ranked partner product"
           )

    assert has_element?(view, "#import-offer-#{offer.id}")
    assert has_element?(view, "#listing-count", "0")

    view |> element("#confirm-business-command") |> render_click()

    assert has_element?(view, "#listing-count", "1")
    refute has_element?(view, "#business-command-preview")
  end

  test "builds a starter catalog with tracked links and reviewable content", ctx do
    create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> form("#starter-business-form", starter_business: %{niche: "kente fashion", count: "3"})
    |> render_submit()

    assert has_element?(view, "#listing-count", "1")
    assert has_element?(view, "#sales-shares article", "Partner Kente Bag")
    assert has_element?(view, "#content-drafts article", "Partner Kente Bag")
    assert has_element?(view, "#content-draft-count", "1")

    {:ok, shares} = Emakola.Suppliers.SalesSharing.list_for_store(ctx.merchant, ctx.store.id)
    assert length(shares) == 3
  end

  test "opens a protected group buy from an imported variant", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
    view |> element("#import-offer-#{offer.id}") |> render_click()
    {:ok, [listing]} = Emakola.Suppliers.ListingImporter.list(ctx.merchant, ctx.store.id)
    mapping = hd(listing.listing_variants)
    deadline = DateTime.add(DateTime.utc_now(), 7, :day)
    refund = DateTime.add(deadline, 2, :day)

    view
    |> form("#group-buy-form",
      group_buy: %{
        listing_variant_id: mapping.id,
        title: "Ten bag circle",
        threshold_quantity: "10",
        unit_price: "60.00",
        deadline: Calendar.strftime(deadline, "%Y-%m-%dT%H:%M"),
        refund_deadline: Calendar.strftime(refund, "%Y-%m-%dT%H:%M")
      }
    )
    |> render_submit()

    assert has_element?(view, "#group-buy-campaigns article", "Ten bag circle")
    assert has_element?(view, "#group-buy-campaigns article", "0/10 paid")
    assert has_element?(view, "#group-buy-campaigns article", "Refund by")
  end

  test "creates a flat team invitation with exact displayed roles and splits", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

    view
    |> form("#sales-team-form",
      sales_team: %{
        name: "Social launch crew",
        collaborator_email: to_string(ctx.partner_merchant.email),
        collaborator_role: "seller",
        owner_percent: "60",
        collaborator_percent: "40"
      }
    )
    |> render_submit()

    assert has_element?(view, "#sales-teams article", "Social launch crew")
    assert {:ok, [team]} = Emakola.Suppliers.SalesTeams.list(ctx.merchant, ctx.store.id)
    assert Enum.sum(Enum.map(team.members, & &1.split_bps)) == 10_000
    assert has_element?(view, "#sales-teams article", "sales_team=#{team.id}")
  end

  test "supplier approves a franchise application and activates its catalog", ctx do
    offer = create_partner_offer!(ctx)
    connect_partner!(ctx)

    {:ok, package} =
      Emakola.Suppliers.Franchises.create(ctx.partner_merchant, ctx.partner.id, %{
        name: "Accra seller kit",
        offer_ids: [offer.id],
        training: %{"lesson" => "Product safety"},
        brand_rules: %{"claims" => "Approved facts only"},
        channel_permissions: [:storefront, :whatsapp],
        territory: "Accra",
        commission_bps: 1_000
      })

    {:ok, package} =
      Emakola.Suppliers.Franchises.publish(
        ctx.partner_merchant,
        ctx.partner.id,
        package.id
      )

    {:ok, enrollment} =
      Emakola.Suppliers.Franchises.apply(ctx.merchant, ctx.store.id, package.id, true)

    token =
      EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(ctx.partner_merchant))

    supplier_conn =
      build_conn()
      |> init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {:ok, view, _html} = live(supplier_conn, ~p"/admin/settings/supply-network/tools")
    assert has_element?(view, "#franchise-enrollment-#{enrollment.id}", ctx.store.name)
    assert has_element?(view, "#approve-franchise-#{enrollment.id}")

    view
    |> element("#approve-franchise-#{enrollment.id}")
    |> render_click()

    assert has_element?(view, "#franchise-enrollment-#{enrollment.id}", "approved")
    assert has_element?(view, "#franchise-enrollment-#{enrollment.id}", "1 products active")

    assert {:ok, [listing]} =
             Emakola.Suppliers.ListingImporter.list(ctx.merchant, ctx.store.id)

    assert listing.offer_id == offer.id
  end

  defp create_partner_offer!(ctx) do
    product = create_product!(ctx.partner, status: :active, title: "Partner Kente Bag")
    variant = create_variant!(product, ctx.partner, price: 6_500, stock_quantity: 10)

    {:ok, offer} =
      Offers.create_draft(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, _terms} =
      Offers.add_variant(ctx.partner_merchant, offer, %{
        source_variant_id: variant.id,
        supplier_price: 5_000,
        suggested_retail_price: 6_500,
        max_retail_price: 7_500
      })

    {:ok, published} = Offers.publish(ctx.partner_merchant, offer)
    published
  end

  defp connect_partner!(ctx) do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, active} = Network.approve(ctx.merchant, pending)
    active
  end

  defp create_inbound_fulfillment!(ctx) do
    customer = create_customer!(ctx.partner, phone: "+233501234567")

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: ctx.partner.id,
          customer_id: customer.id,
          shipping_address: %{"phone" => customer.phone, "city" => "Accra"}
        },
        authorize?: false
      )

    supplier = create_supplier!(ctx.partner, linked_store_id: ctx.store.id)
    create_fulfillment!(order, ctx.partner, supplier_id: supplier.id)
  end
end
