defmodule Emakola.Suppliers do
  @moduledoc "Suppliers domain — third-party suppliers for dropshipped products."
  use Ash.Domain

  resources do
    resource Emakola.Suppliers.Supplier do
      define(:create_supplier, action: :create)
      define(:update_supplier, action: :update)
      define(:list_suppliers_by_store, action: :list_by_store, args: [:store_id])
      define(:list_active_suppliers_by_store, action: :list_active_by_store, args: [:store_id])
      define(:get_supplier_by_store, action: :get_by_store, args: [:id, :store_id])
    end

    resource Emakola.Suppliers.SupplierLedgerEntry do
      define(:list_ledger_entries_by_supplier,
        action: :list_by_supplier,
        args: [:supplier_id]
      )

      define(:mark_ledger_entry_paid, action: :mark_paid)
    end

    resource Emakola.Suppliers.SupplyConnection do
      define(:request_supply_connection, action: :request)
      define(:list_supply_connections_for_store, action: :for_store, args: [:store_id])
      define(:approve_supply_connection, action: :approve)
      define(:reject_supply_connection, action: :reject)
      define(:suspend_supply_connection, action: :suspend)
      define(:reactivate_supply_connection, action: :reactivate)
      define(:terminate_supply_connection, action: :terminate)
    end

    resource Emakola.Suppliers.SupplierOffer do
      define(:create_supplier_offer, action: :create_draft)
      define(:list_supplier_offers_owned_by_store, action: :owned_by_store, args: [:store_id])
      define(:publish_supplier_offer, action: :publish)
      define(:pause_supplier_offer, action: :pause)
      define(:archive_supplier_offer, action: :archive)
    end

    resource Emakola.Suppliers.SupplierOfferVariant do
      define(:create_supplier_offer_variant, action: :create)
    end

    resource Emakola.Suppliers.ResellerListing do
      define(:create_reseller_listing, action: :create)
      define(:list_reseller_listings_for_store, action: :for_store, args: [:store_id])
    end

    resource Emakola.Suppliers.ResellerListingVariant do
      define(:create_reseller_listing_variant, action: :create)
    end

    resource Emakola.Suppliers.ResellerListingImage do
      define(:create_reseller_listing_image, action: :create)
    end

    resource Emakola.Suppliers.SalesShare do
      define(:create_sales_share, action: :create)
    end

    resource Emakola.Suppliers.SalesShareConversion do
      define(:record_sales_share_conversion, action: :record)
    end

    resource Emakola.Suppliers.IncomeGoal do
      define(:list_income_goals_for_store, action: :for_store, args: [:store_id])
    end

    resource Emakola.Suppliers.ContentDraft do
      define(:list_content_drafts_for_store, action: :for_store, args: [:store_id])
    end

    resource Emakola.Suppliers.GroupBuyCampaign do
      define(:list_group_buy_campaigns_for_store, action: :for_store, args: [:store_id])
    end

    resource(Emakola.Suppliers.GroupBuyCommitment)

    resource Emakola.Suppliers.SalesTeam do
      define(:list_sales_teams_for_store, action: :for_store, args: [:store_id])
    end

    resource(Emakola.Suppliers.SalesTeamMember)
    resource(Emakola.Suppliers.SalesTeamSettlement)

    resource Emakola.Suppliers.FranchisePackage do
      define(:list_franchise_packages_owned_by_store, action: :owned_by_store, args: [:store_id])
    end

    resource(Emakola.Suppliers.FranchiseEnrollment)
    resource(Emakola.Suppliers.CommercePassport)
    resource(Emakola.Suppliers.ReputationSignal)
    resource(Emakola.Suppliers.ReputationAppeal)
    resource(Emakola.Suppliers.InventoryEligibilityPolicy)
    resource(Emakola.Suppliers.InventoryReservation)
    resource(Emakola.Suppliers.InventoryReservationConsumption)
    resource(Emakola.Suppliers.PartnerCreditOffer)
    resource(Emakola.Suppliers.PartnerCreditAgreement)
    resource(Emakola.Suppliers.PartnerCreditRepayment)
    resource(Emakola.Suppliers.ProtectedPreorder)
    resource(Emakola.Suppliers.PreorderMilestone)
    resource(Emakola.Suppliers.PreorderDeposit)
  end
end
