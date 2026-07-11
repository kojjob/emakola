defmodule Emakola.Suppliers.ProtectedPreordersTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo
  import Emakola.Factory
  import Ecto.Query

  defmodule SelfReportingGateway do
    @moduledoc "Runs in the caller's process; reports every refund to the test pid."
    def process_refund(reference, amount) do
      send(self(), {:refund_called, reference, amount})
      {:ok, %{refund_reference: "REF-#{reference}"}}
    end
  end

  alias Emakola.Suppliers.{
    CommercePassports,
    PreorderDeposit,
    PreorderMilestone,
    ProtectedPreorder,
    ProtectedPreorders,
    ReputationSignal
  }

  setup do
    {actor, store} = create_merchant_with_store!(%{name: "Preorder Supplier"})
    customer = create_customer!(store)
    {:ok, _passport} = CommercePassports.refresh(actor, store.id)
    {:ok, actor: actor, store: store, customer: customer}
  end

  test "requires complete disclosures, milestones, and independent funds-flow approvals", ctx do
    assert {:error, :complete_disclosures_required} =
             ProtectedPreorders.create(
               ctx.actor,
               ctx.store.id,
               %{attrs() | customer_disclosures: %{}},
               milestones()
             )

    assert {:error, :milestones_required} =
             ProtectedPreorders.create(ctx.actor, ctx.store.id, attrs(), [])

    unapproved = %{
      attrs()
      | legal_approval_reference: nil,
        payment_provider_approval_reference: nil
    }

    assert {:ok, preorder} =
             ProtectedPreorders.create(ctx.actor, ctx.store.id, unapproved, milestones())

    assert {:error, :funds_flow_not_approved} =
             ProtectedPreorders.open(ctx.actor, ctx.store.id, preorder.id)
  end

  test "locks exact deposit economics, confirms once, and reaches minimum demand", ctx do
    {:ok, preorder} = create_open(ctx)
    assert preorder.customer_disclosures["automatic_refund_rule"]
    assert length(preorder.milestones) == 2

    assert {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)
    assert deposit.amount == 4_000
    payment = create_payment!(ctx.store, amount: 4_000)

    deposit
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    assert :ok = ProtectedPreorders.confirm_payment(payment)
    assert :ok = ProtectedPreorders.confirm_payment(payment)
    funded = Ash.get!(ProtectedPreorder, preorder.id, authorize?: false)
    assert funded.committed_quantity == 2
    assert funded.status == :funded
    assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :paid
  end

  test "milestone evidence advances production and overdue failure refunds exactly", ctx do
    {:ok, preorder} = create_open(ctx)
    {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)
    payment = create_payment!(ctx.store, amount: deposit.amount)

    deposit
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    :ok = ProtectedPreorders.confirm_payment(payment)

    first = preorder.milestones |> Enum.sort_by(& &1.position) |> hd()

    assert {:error, :evidence_required} =
             ProtectedPreorders.complete_milestone(ctx.actor, ctx.store.id, first.id, %{})

    assert {:ok, completed} =
             ProtectedPreorders.complete_milestone(ctx.actor, ctx.store.id, first.id, %{
               "inspection_report" => "IPFS-proof"
             })

    assert completed.status == :completed
    assert Ash.get!(ProtectedPreorder, preorder.id, authorize?: false).status == :production

    second = preorder.milestones |> Enum.sort_by(& &1.position) |> List.last()

    Emakola.Repo.update_all(
      from(m in "preorder_milestones", where: m.id == type(^second.id, Ecto.UUID)),
      set: [due_at: DateTime.add(DateTime.utc_now(), -60)]
    )

    assert {:ok, [{:ok, deposit_id}]} =
             ProtectedPreorders.fail_and_refund(
               preorder.id,
               "Production milestone missed",
               Emakola.Payments.Gateways.Mock
             )

    assert deposit_id == deposit.id
    assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :refunded
    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :refunded
    assert Ash.get!(ProtectedPreorder, preorder.id, authorize?: false).status == :refunded
    assert Ash.get!(PreorderMilestone, second.id, authorize?: false).status == :missed

    assert Enum.any?(
             Ash.read!(ReputationSignal, authorize?: false),
             &(&1.reason_code == "PREORDER_MILESTONE_FAILURE")
           )
  end

  test "holds deposits out of payout until every milestone is fulfilled", ctx do
    {:ok, preorder} = create_open(ctx)
    {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)

    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: ctx.store.id,
          amount: deposit.amount,
          gateway: :paystack,
          gateway_reference: "preorder-hold-#{Ecto.UUID.generate()}",
          payout_held: true,
          payout_hold_reason: "protected_preorder_deposit"
        },
        authorize?: false
      )

    deposit
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    :ok = ProtectedPreorders.confirm_payment(payment)
    assert Emakola.Payments.PayoutService.outstanding_payments(ctx.store.id) == []

    Enum.each(preorder.milestones, fn milestone ->
      assert {:ok, _} =
               ProtectedPreorders.complete_milestone(
                 ctx.actor,
                 ctx.store.id,
                 milestone.id,
                 %{"proof" => "verified-#{milestone.position}"}
               )
    end)

    assert {:ok, fulfilled} = ProtectedPreorders.fulfill(ctx.actor, ctx.store.id, preorder.id)
    assert fulfilled.status == :fulfilled
    released = Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false)
    refute released.payout_held
    assert released.payout_released_at

    assert Enum.map(Emakola.Payments.PayoutService.outstanding_payments(ctx.store.id), & &1.id) ==
             [payment.id]
  end

  defp create_open(ctx) do
    {:ok, preorder} = ProtectedPreorders.create(ctx.actor, ctx.store.id, attrs(), milestones())
    ProtectedPreorders.open(ctx.actor, ctx.store.id, preorder.id)
  end

  defp attrs do
    now = DateTime.utc_now()

    %{
      listing_variant_id: Ecto.UUID.generate(),
      title: "Solar freezer production run",
      description: "Protected production preorder",
      unit_price: 10_000,
      deposit_amount: 2_000,
      minimum_quantity: 2,
      maximum_quantity: 5,
      commitment_deadline: DateTime.add(now, 7, :day),
      delivery_window_start: Date.add(Date.utc_today(), 30),
      delivery_window_end: Date.add(Date.utc_today(), 45),
      automatic_refund_deadline: DateTime.add(now, 20, :day),
      legal_approval_reference: "LEGAL-2026-01",
      payment_provider_approval_reference: "PAYSTACK-APPROVAL-01",
      customer_disclosures: %{
        "deposit_treatment" => "Protected until milestones",
        "automatic_refund_rule" => true,
        "delivery_window" => "30–45 days",
        "supplier_identity" => "Preorder Supplier"
      }
    }
  end

  defp milestones do
    now = DateTime.utc_now()

    [
      %{
        title: "Materials inspected",
        due_at: DateTime.add(now, 10, :day),
        evidence_requirements: "Inspection report"
      },
      %{
        title: "Production complete",
        due_at: DateTime.add(now, 15, :day),
        evidence_requirements: "Batch photos and serials"
      }
    ]
  end

  # Post-merge hardening (2026-07-11 review): no successful deposit payment may
  # be stranded — late webhooks, crashed refunds, and failed gateway calls must
  # all converge on :refunded via the sweep.
  describe "refund recovery" do
    test "a deposit paid after failure is swept for refund, not stranded", ctx do
      {:ok, preorder} = create_open(ctx)
      {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)
      payment = create_payment!(ctx.store, amount: deposit.amount)

      deposit
      |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
      |> Ash.update!(authorize?: false)

      # The refund deadline passes and the preorder fails while the deposit is
      # still pending (its charge.success has not arrived yet).
      force_refund_deadline_past!(preorder.id)

      {:ok, _results} =
        ProtectedPreorders.fail_and_refund(
          preorder.id,
          "Deadline missed",
          Emakola.Payments.Gateways.Mock
        )

      # The late webhook now lands with a successful charge.
      payment =
        payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

      assert :ok = ProtectedPreorders.confirm_payment(payment)
      assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :paid

      reloaded = Ash.get!(ProtectedPreorder, preorder.id, authorize?: false)
      assert reloaded.status in [:failed, :refunded]

      # The sweep must re-enqueue this preorder even though it is terminal.
      assert :ok =
               Emakola.Suppliers.Workers.ProtectedPreorderExpiryWorker.perform(%Oban.Job{
                 args: %{}
               })

      assert_enqueued(
        worker: Emakola.Suppliers.Workers.ProtectedPreorderExpiryWorker,
        args: %{preorder_id: preorder.id}
      )

      # And the per-preorder job completes the refund.
      {:ok, _results} =
        ProtectedPreorders.fail_and_refund(
          preorder.id,
          "Late deposit refund",
          Emakola.Payments.Gateways.Mock
        )

      assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :refunded

      assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status ==
               :refunded
    end

    test "a stranded :refunding deposit is re-attempted", ctx do
      {:ok, preorder} = create_open(ctx)
      deposit = paid_deposit!(ctx, preorder)
      force_refund_deadline_past!(preorder.id)
      force_deposit_status!(deposit.id, "refunding")

      {:ok, _results} =
        ProtectedPreorders.fail_and_refund(preorder.id, "Recovery", SelfReportingGateway)

      assert_received {:refund_called, _reference, 4_000}
      assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :refunded
      assert Ash.get!(ProtectedPreorder, preorder.id, authorize?: false).status == :refunded
    end

    test "a :refunding deposit whose payment is already refunded completes without a gateway call",
         ctx do
      {:ok, preorder} = create_open(ctx)
      deposit = paid_deposit!(ctx, preorder)
      force_refund_deadline_past!(preorder.id)
      force_deposit_status!(deposit.id, "refunding")

      Ash.get!(Emakola.Payments.Payment, deposit.payment_id, authorize?: false)
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: deposit.amount})
      |> Ash.update!(authorize?: false)

      {:ok, _results} =
        ProtectedPreorders.fail_and_refund(preorder.id, "Bookkeeping", SelfReportingGateway)

      refute_received {:refund_called, _, _}
      assert Ash.get!(PreorderDeposit, deposit.id, authorize?: false).status == :refunded
    end

    test "the deposit state machine rejects illegal transitions", ctx do
      {:ok, preorder} = create_open(ctx)
      {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)

      assert_raise Ash.Error.Invalid, fn ->
        deposit
        |> Ash.Changeset.for_update(:refunded, %{refund_reference: "REF-ILLEGAL"})
        |> Ash.update!(authorize?: false)
      end
    end
  end

  defp paid_deposit!(ctx, preorder) do
    {:ok, deposit} = ProtectedPreorders.reserve(preorder.id, ctx.customer, 2)
    payment = create_payment!(ctx.store, amount: deposit.amount)

    deposit
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    :ok = ProtectedPreorders.confirm_payment(payment)
    Ash.get!(PreorderDeposit, deposit.id, authorize?: false)
  end

  defp force_refund_deadline_past!(preorder_id) do
    Emakola.Repo.update_all(
      from(p in "protected_preorders", where: p.id == type(^preorder_id, Ecto.UUID)),
      set: [automatic_refund_deadline: DateTime.add(DateTime.utc_now(), -60)]
    )
  end

  defp force_deposit_status!(deposit_id, status) do
    Emakola.Repo.update_all(
      from(d in "preorder_deposits", where: d.id == type(^deposit_id, Ecto.UUID)),
      set: [status: status]
    )
  end
end
