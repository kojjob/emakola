defmodule Emakola.Suppliers.PartnerCreditTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Suppliers.{
    CommercePassports,
    PartnerCredit,
    PartnerCreditAgreement,
    PartnerCreditRepayment
  }

  setup do
    {provider, provider_store} = create_merchant_with_store!(%{name: "Capital Supplier"})
    {borrower, borrower_store} = create_merchant_with_store!(%{name: "Seller"})
    {:ok, passport} = CommercePassports.refresh(borrower, borrower_store.id)

    attrs = %{
      provider_type: :supplier,
      provider_store_id: provider_store.id,
      provider_name: "Capital Supplier",
      creditor_subaccount_code: "ACCT_credit",
      borrower_store_id: borrower_store.id,
      minimum_tier: :starter,
      principal_amount: 10_000,
      fee_amount: 1_000,
      repayment_bps: 2_500,
      term_days: 90,
      reason_code: "STARTER_TRADE_CREDIT",
      decision_snapshot: %{"passport_id" => passport.id, "tier" => "starter"}
    }

    {:ok,
     provider: provider,
     provider_store: provider_store,
     borrower: borrower,
     borrower_store: borrower_store,
     attrs: attrs}
  end

  test "requires provider authority, licensed-partner evidence, and informed consent", context do
    assert {:error, :forbidden} = PartnerCredit.create_offer(context.borrower, context.attrs)

    assert {:error, :license_reference_required} =
             PartnerCredit.create_offer(context.provider, %{
               context.attrs
               | provider_type: :licensed_partner
             })

    assert {:ok, offer} = PartnerCredit.create_offer(context.provider, context.attrs)

    assert {:error, :informed_consent_or_eligibility_required} =
             PartnerCredit.accept(context.borrower, offer.id, false)
  end

  test "freezes disclosures, needs disbursement evidence, and carves sales only", context do
    {:ok, offer} = PartnerCredit.create_offer(context.provider, context.attrs)
    {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
    assert agreement.consent_snapshot["total_due"] == 11_000
    assert agreement.consent_snapshot["consent"]

    assert {:error, :disbursement_evidence_required} =
             PartnerCredit.activate(context.provider, agreement.id, " ")

    assert {:ok, active} = PartnerCredit.activate(context.provider, agreement.id, "BANK-001")
    assert active.status == :active

    allocations = [
      %{
        role: :merchant,
        recipient_store_id: context.borrower_store.id,
        amount: 8_000,
        subaccount_code: "ACCT_seller"
      },
      %{role: :platform, recipient_store_id: nil, amount: 200, subaccount_code: nil}
    ]

    carved = PartnerCredit.carve_sales_proceeds(allocations, context.borrower_store.id)
    assert Enum.find(carved, &(&1.role == :merchant)).amount == 6_000
    assert Enum.find(carved, &(&1.role == :platform)).amount == 200
    credit = Enum.find(carved, &(&1.role == :credit_partner))
    assert credit.amount == 2_000
    assert credit.credit_agreement_id == agreement.id
    assert Enum.sum(Enum.map(carved, & &1.amount)) == 8_200
  end

  test "settlement is idempotent and proportional refund reopens outstanding", context do
    {:ok, offer} = PartnerCredit.create_offer(context.provider, context.attrs)
    {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
    {:ok, _} = PartnerCredit.activate(context.provider, agreement.id, "BANK-002")
    payment = create_payment!(context.borrower_store, amount: 8_000)
    split = %{role: :credit_partner, credit_agreement_id: agreement.id, amount: 2_000}

    assert :ok = PartnerCredit.record_settlement(payment, [split])
    assert :ok = PartnerCredit.record_settlement(payment, [split])
    updated = Ash.get!(PartnerCreditAgreement, agreement.id, authorize?: false)
    assert updated.outstanding_amount == 9_000
    assert length(Ash.read!(PartnerCreditRepayment, authorize?: false)) == 1

    refunded = %{payment | refunded_amount: 4_000}
    assert :ok = PartnerCredit.reconcile_refund(refunded, [split])
    assert :ok = PartnerCredit.reconcile_refund(refunded, [split])

    assert Ash.get!(PartnerCreditAgreement, agreement.id, authorize?: false).outstanding_amount ==
             10_000
  end
end
