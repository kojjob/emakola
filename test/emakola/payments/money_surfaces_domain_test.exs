defmodule Emakola.Payments.MoneySurfacesDomainTest do
  @moduledoc """
  Domain foundations for the money-surfaces UI elevation (PR-1, Task 1):

    * `PaymentSplit.needs_remediation` — the manual-remediation worklist for
      splits `release_from_payout` stamped as unreclaimable.
    * `Payout.recent_by_store` — a bounded, newest-first payout history a
      store member can read (merchant read-only policy, mirroring
      PaymentSplit's shape).
    * `approve_both_bases/3` (finance_live.ex) stamping a shared
      `approval_ref` into both payout bases created by one approval click.

  This PR changes zero money behavior — reads and metadata stamping only.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.Workers.PayoutWorker

  # ── PaymentSplit.needs_remediation ─────────────────────────────────────

  describe "needs_remediation" do
    defp unreclaimable_split!(store, payment, attrs \\ %{}) do
      split =
        %{
          store_id: store.id,
          payment_id: payment.id,
          role: :merchant,
          recipient_store_id: store.id,
          amount: 10_000,
          settlement_method: :internal_hold
        }
        |> Map.merge(Map.new(attrs))
        |> then(&Payments.create_payment_split!(&1, authorize?: false))

      split
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: split.amount})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:release_from_payout, %{})
      |> Ash.update!(authorize?: false)
    end

    defp settled_split!(store, payment, attrs \\ %{}) do
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: 10_000,
        settlement_method: :internal_hold
      }
      |> Map.merge(Map.new(attrs))
      |> then(&Payments.create_payment_split!(&1, authorize?: false))
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
    end

    test "a split stamped unreclaimable appears; settled/unstamped ones don't" do
      store = Factory.create_store!()
      payment_a = Factory.create_payment!(store, %{amount: 10_000})
      payment_b = Factory.create_payment!(store, %{amount: 10_000})

      remediate = unreclaimable_split!(store, payment_a)
      settled_split!(store, payment_b)

      assert {:ok, splits} = Payments.list_remediation_splits(authorize?: false)
      assert Enum.map(splits, & &1.id) == [remediate.id]
      assert remediate.recovery_breakdown["unreclaimable_release"] == true
    end

    test "sorted updated_at desc" do
      store = Factory.create_store!()
      payment_a = Factory.create_payment!(store, %{amount: 10_000})
      payment_b = Factory.create_payment!(store, %{amount: 10_000})

      older = unreclaimable_split!(store, payment_a)
      newer = unreclaimable_split!(store, payment_b)

      assert {:ok, splits} = Payments.list_remediation_splits(authorize?: false)
      assert Enum.map(splits, & &1.id) == [newer.id, older.id]
    end
  end

  # ── Payout.recent_by_store ──────────────────────────────────────────────

  describe "recent_by_store" do
    defp payout!(store, attrs \\ %{}) do
      Payments.create_payout!(
        Map.merge(
          %{
            store_id: store.id,
            amount: 10_000,
            currency: "GHS",
            transfer_reference: "PO-#{Ash.UUID.generate()}"
          },
          Map.new(attrs)
        ),
        authorize?: false
      )
    end

    test "returns only that store's payouts, newest first" do
      store_a = Factory.create_store!(%{name: "Store A"})
      store_b = Factory.create_store!(%{name: "Store B"})

      older = payout!(store_a)
      newer = payout!(store_a)
      payout!(store_b)

      assert {:ok, payouts} = Payments.list_store_payouts(store_a.id, authorize?: false)
      assert Enum.map(payouts, & &1.id) == [newer.id, older.id]
    end

    test "a member merchant CAN read their store's payouts" do
      {merchant, store} = Factory.create_merchant_with_store!()
      payout!(store)

      assert {:ok, [_payout]} =
               Payments.list_store_payouts(store.id, actor: merchant, tenant: store.id)
    end

    test "a non-member merchant CANNOT read another store's payouts" do
      {_owner, store} = Factory.create_merchant_with_store!()
      {other_merchant, _other_store} = Factory.create_merchant_with_store!()
      payout!(store)

      assert {:error, %Ash.Error.Forbidden{}} =
               Payments.list_store_payouts(store.id, actor: other_merchant, tenant: store.id)
    end
  end

  # ── approve_both_bases approval_ref grouping ────────────────────────────

  describe "approve_both_bases stamps a shared approval_ref" do
    defp momo_account!(store) do
      {:ok, _} =
        Emakola.Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{
              "method" => "mobile_money",
              "provider" => "mtn",
              "number" => "0244123456",
              "account_name" => "Kwame Owusu"
            }
          },
          authorize?: false
        )
    end

    defp settled_internal_split!(store, payment, attrs) do
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: 10_000,
        settlement_method: :internal_hold
      }
      |> Map.merge(Map.new(attrs))
      |> then(&Ash.Changeset.for_create(PaymentSplit, :create, &1))
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
    end

    defp success_payment!(store, attrs) do
      store
      |> Factory.create_payment!(attrs)
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)
    end

    test "approving a both-bases store yields two payouts sharing one approval_ref", %{
      conn: conn
    } do
      {conn, _user, _session} = setup_platform_staff(conn)

      store = Factory.create_store!(%{name: "Dual Basis Grouping Co"})
      momo_account!(store)
      success_payment!(store, %{amount: 80_000})

      split_payment = Factory.create_payment!(store, %{amount: 20_000})
      settled_internal_split!(store, split_payment, %{amount: 15_000})

      {:ok, view, _html} = live(conn, ~p"/platform/finance")

      view
      |> element("button[phx-click='approve_payout'][phx-value-store_id='#{store.id}']")
      |> render_click()

      payouts = Payments.list_payouts_by_store!(store.id, authorize?: false)
      assert length(payouts) == 2

      refs = payouts |> Enum.map(& &1.metadata["approval_ref"]) |> Enum.uniq()
      assert [ref] = refs
      assert is_binary(ref)
      assert String.starts_with?(ref, "appr_")

      # Both payouts enqueued — count-based (house pattern, see
      # finance_live_internal_test.exs): Oban's unique-conflict returns the
      # *attempted* job on a dupe, so a count/id-set check is the honest
      # assertion, not "assert_enqueued" per id alone.
      jobs = all_enqueued(worker: PayoutWorker)
      assert length(jobs) == 2

      enqueued_payout_ids = Enum.map(jobs, & &1.args["payout_id"])
      assert Enum.sort(enqueued_payout_ids) == Enum.sort(Enum.map(payouts, & &1.id))
    end
  end

  # ── approval_ref stamping must never jeopardize money movement ─────────
  #
  # process_basis/6 stamps approval_ref AFTER PayoutWorker.enqueue/1 and the
  # audit log — never before — precisely so a stamping failure can't strand
  # an already-committed payout (the stranding shape approve_both_bases/3's
  # own docstring exists to prevent). This is proven two ways:
  #
  #   1. Below: update_payout_metadata genuinely returns {:error, _} for a
  #      stale payout — the log-and-continue branch in process_basis is
  #      reachable, not dead code.
  #   2. By inspection of finance_live.ex: PayoutWorker.enqueue/1 and
  #      PlatformAudit.log/3 are unconditional statements preceding the
  #      `case update_payout_metadata(...)` — not inside it — so nothing the
  #      stamp does can prevent them from having already run.
  #
  # Arrangement limitation: driving an ACTUAL stamp failure through the full
  # LiveView approve click (rather than testing update_payout_metadata's
  # failure mode directly) would require stubbing Emakola.Payments mid-call,
  # since process_basis/6 is private and the whole approve_both_bases/3 flow
  # runs synchronously within one handle_event. The project has no
  # mocking/stubbing library for plain modules (Mox exists only for
  # behaviour-gated external gateways), so that injection isn't cheaply
  # arrangeable — hence the two-part proof above instead of a single
  # end-to-end failure test.
  describe "approval_ref stamping tolerates a failed stamp" do
    test "update_payout_metadata surfaces {:error, _} for a payout deleted underneath it" do
      store = Factory.create_store!()

      payout =
        Payments.create_payout!(
          %{
            store_id: store.id,
            amount: 10_000,
            currency: "GHS",
            transfer_reference: "PO-#{Ash.UUID.generate()}"
          },
          authorize?: false
        )

      # No destroy action exists on Payout (system rows are never deleted in
      # production) — go around Ash to simulate the row vanishing between
      # creation and the stamp attempt (e.g. a concurrent admin action).
      Emakola.Repo.delete_all(from(p in "payouts", where: p.id == type(^payout.id, Ecto.UUID)))

      assert {:error, %Ash.Error.Invalid{}} =
               Payments.update_payout_metadata(payout, %{"approval_ref" => "appr_deadbeef"},
                 authorize?: false
               )
    end
  end
end
