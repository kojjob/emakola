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

  # Post-merge hardening (2026-07-11 review). These tests pin the invariant the
  # fixes rely on: the outstanding balance is always RECOMPUTED from the
  # repayment ledger under a row lock — never read-modify-written — so crashed
  # or concurrent writers converge instead of losing updates.
  describe "money-path hardening" do
    test "settlement recomputes the balance from the ledger, not a stale decrement", context do
      {:ok, offer} = PartnerCredit.create_offer(context.provider, context.attrs)
      {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
      {:ok, _} = PartnerCredit.activate(context.provider, agreement.id, "BANK-010")

      payment_one = create_payment!(context.borrower_store, amount: 8_000)
      split_one = %{role: :credit_partner, credit_agreement_id: agreement.id, amount: 2_000}
      assert :ok = PartnerCredit.record_settlement(payment_one, [split_one])

      # Simulate a lost update: the balance column drifts from the ledger.
      Ash.get!(PartnerCreditAgreement, agreement.id, authorize?: false)
      |> Ash.Changeset.for_update(:balance, %{outstanding_amount: 11_000, status: :active})
      |> Ash.update!(authorize?: false)

      payment_two = create_payment!(context.borrower_store, amount: 4_000)
      split_two = %{role: :credit_partner, credit_agreement_id: agreement.id, amount: 1_000}
      assert :ok = PartnerCredit.record_settlement(payment_two, [split_two])

      assert Ash.get!(PartnerCreditAgreement, agreement.id, authorize?: false).outstanding_amount ==
               8_000
    end

    test "a refund replay heals a balance a crashed reconcile left unrestored", context do
      {:ok, offer} = PartnerCredit.create_offer(context.provider, context.attrs)
      {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
      {:ok, _} = PartnerCredit.activate(context.provider, agreement.id, "BANK-011")

      payment = create_payment!(context.borrower_store, amount: 8_000)
      split = %{role: :credit_partner, credit_agreement_id: agreement.id, amount: 2_000}
      assert :ok = PartnerCredit.record_settlement(payment, [split])

      # Crash aftermath: the reversal was recorded but the balance restore was lost.
      [repayment] = Ash.read!(PartnerCreditRepayment, authorize?: false)

      repayment
      |> Ash.Changeset.for_update(:reverse, %{reversed_amount: 1_000})
      |> Ash.update!(authorize?: false)

      refunded = %{payment | refunded_amount: 4_000}
      assert :ok = PartnerCredit.reconcile_refund(refunded, [split])

      # total_due 11_000 minus net repayments (2_000 - 1_000) = 10_000
      assert Ash.get!(PartnerCreditAgreement, agreement.id, authorize?: false).outstanding_amount ==
               10_000
    end

    test "carve capacity excludes in-flight pending carves", context do
      attrs = %{context.attrs | principal_amount: 2_000, fee_amount: 500, repayment_bps: 10_000}
      {:ok, offer} = PartnerCredit.create_offer(context.provider, attrs)
      {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
      {:ok, _} = PartnerCredit.activate(context.provider, agreement.id, "BANK-012")

      in_flight = create_payment!(context.borrower_store, amount: 8_000)

      Emakola.Payments.create_payment_split!(
        %{
          store_id: context.borrower_store.id,
          payment_id: in_flight.id,
          role: :credit_partner,
          recipient_store_id: context.provider_store.id,
          credit_agreement_id: agreement.id,
          amount: 2_000
        },
        authorize?: false
      )

      allocations = [
        %{
          role: :merchant,
          recipient_store_id: context.borrower_store.id,
          amount: 8_000,
          subaccount_code: "ACCT_seller"
        }
      ]

      carved = PartnerCredit.carve_sales_proceeds(allocations, context.borrower_store.id)
      credit = Enum.find(carved, &(&1.role == :credit_partner))

      # outstanding 2_500 minus the 2_000 already carved in flight = 500
      assert credit.amount == 500
      assert Enum.find(carved, &(&1.role == :merchant)).amount == 7_500
    end

    test "stale in-flight carves no longer reserve capacity", context do
      attrs = %{context.attrs | principal_amount: 2_000, fee_amount: 500, repayment_bps: 10_000}
      {:ok, offer} = PartnerCredit.create_offer(context.provider, attrs)
      {:ok, agreement} = PartnerCredit.accept(context.borrower, offer.id, true)
      {:ok, _} = PartnerCredit.activate(context.provider, agreement.id, "BANK-013")

      abandoned = create_payment!(context.borrower_store, amount: 8_000)

      stale_split =
        Emakola.Payments.create_payment_split!(
          %{
            store_id: context.borrower_store.id,
            payment_id: abandoned.id,
            role: :credit_partner,
            recipient_store_id: context.provider_store.id,
            credit_agreement_id: agreement.id,
            amount: 2_000
          },
          authorize?: false
        )

      three_days_ago = DateTime.add(DateTime.utc_now(), -3, :day)

      Emakola.Repo.update_all(
        Ecto.Query.from(s in "payment_splits",
          where: s.id == type(^stale_split.id, Ecto.UUID)
        ),
        set: [inserted_at: three_days_ago]
      )

      allocations = [
        %{
          role: :merchant,
          recipient_store_id: context.borrower_store.id,
          amount: 8_000,
          subaccount_code: "ACCT_seller"
        }
      ]

      carved = PartnerCredit.carve_sales_proceeds(allocations, context.borrower_store.id)
      assert Enum.find(carved, &(&1.role == :credit_partner)).amount == 2_500
    end

    test "a second active agreement cannot be accepted", context do
      {:ok, offer_one} = PartnerCredit.create_offer(context.provider, context.attrs)
      {:ok, _agreement} = PartnerCredit.accept(context.borrower, offer_one.id, true)

      {:ok, offer_two} = PartnerCredit.create_offer(context.provider, context.attrs)

      assert {:error, :active_agreement_exists} =
               PartnerCredit.accept(context.borrower, offer_two.id, true)
    end

    test "the database rejects a second open agreement even when service guards are bypassed",
         context do
      {:ok, offer_one} = PartnerCredit.create_offer(context.provider, context.attrs)
      {:ok, agreement_one} = PartnerCredit.accept(context.borrower, offer_one.id, true)
      {:ok, _} = PartnerCredit.activate(context.provider, agreement_one.id, "BANK-014")

      {:ok, offer_two} = PartnerCredit.create_offer(context.provider, context.attrs)
      {:ok, passport} = CommercePassports.refresh(context.borrower, context.borrower_store.id)

      # Two open agreements previously crashed every checkout for the store
      # (read_one! raised). The partial unique index makes the state unrepresentable.
      error =
        assert_raise Ash.Error.Unknown, fn ->
          PartnerCreditAgreement
          |> Ash.Changeset.for_create(:create, %{
            offer_id: offer_two.id,
            borrower_store_id: context.borrower_store.id,
            passport_id: passport.id,
            principal_amount: 10_000,
            fee_amount: 1_000,
            total_due: 11_000,
            outstanding_amount: 11_000,
            repayment_bps: 2_500,
            consent_snapshot: %{"consent" => true},
            consented_at: DateTime.utc_now()
          })
          |> Ash.create!(authorize?: false)
        end

      assert Exception.message(error) =~ "one_open_per_borrower"
    end

    test "licensed-partner offers require a platform staff actor", context do
      licensed =
        context.attrs
        |> Map.put(:provider_type, :licensed_partner)
        |> Map.put(:license_reference, "NBFI-2026-001")

      assert {:error, :forbidden} = PartnerCredit.create_offer(context.provider, licensed)

      platform_staff = create_platform_owner!()
      assert {:ok, _offer} = PartnerCredit.create_offer(platform_staff, licensed)
    end
  end
end
