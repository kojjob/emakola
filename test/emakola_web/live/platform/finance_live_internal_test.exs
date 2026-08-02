defmodule EmakolaWeb.Platform.FinanceLiveInternalTest do
  @moduledoc """
  Platform finance approve flow draining BOTH payout bases — legacy un-split
  payments AND payable internal-hold allocations — in a single click.
  Task 7 of the internal-settlement Phase 2.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.Workers.PayoutWorker

  defp success_payment!(store, attrs) do
    store
    |> Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

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

  setup %{conn: conn} do
    {conn, user, _session} = setup_platform_staff(conn)
    %{conn: conn, user: user}
  end

  test "approve on a store with both an outstanding payment and a payable split creates two payouts",
       %{conn: conn, user: user} do
    store = Factory.create_store!(%{name: "Dual Basis Co"})
    momo_account!(store)
    success_payment!(store, %{amount: 80_000})

    split_payment = Factory.create_payment!(store, %{amount: 20_000})
    settled_internal_split!(store, split_payment, %{amount: 15_000})

    {:ok, view, _html} = live(conn, ~p"/platform/finance")

    html =
      view
      |> element("button[phx-value-store_id='#{store.id}']")
      |> render_click()

    assert html =~ "queued" or html =~ "Payout"

    payouts = Emakola.Payments.list_payouts_by_store!(store.id, authorize?: false)
    assert length(payouts) == 2
    assert Enum.sort(Enum.map(payouts, & &1.basis)) == [:allocations, :payments]

    payments_payout = Enum.find(payouts, &(&1.basis == :payments))
    allocations_payout = Enum.find(payouts, &(&1.basis == :allocations))
    assert payments_payout.amount == 80_000
    assert allocations_payout.amount == 15_000

    # Exactly 2 PayoutWorker jobs, one per payout — a count-based assertion,
    # since Oban's unique-conflict returns the *attempted* job on a dupe.
    jobs = all_enqueued(worker: PayoutWorker)
    assert length(jobs) == 2

    enqueued_payout_ids = Enum.map(jobs, & &1.args["payout_id"])

    assert Enum.sort(enqueued_payout_ids) ==
             Enum.sort([payments_payout.id, allocations_payout.id])

    page = Emakola.Accounts.list_platform_audit_logs!(authorize?: false, page: [limit: 200])

    audited_ids =
      page.results
      |> Enum.filter(&(&1.action == :payout_approved and &1.actor_id == user.id))
      |> Enum.map(& &1.metadata["payout_id"])

    assert payments_payout.id in audited_ids
    assert allocations_payout.id in audited_ids
  end

  test "approve on a store with only an internal balance approves cleanly (no legacy error)",
       %{conn: conn, user: user} do
    store = Factory.create_store!(%{name: "Allocations Only Co"})
    momo_account!(store)
    payment = Factory.create_payment!(store, %{amount: 20_000})
    settled_internal_split!(store, payment, %{amount: 12_000})

    {:ok, view, _html} = live(conn, ~p"/platform/finance")

    html =
      view
      |> element("button[phx-value-store_id='#{store.id}']")
      |> render_click()

    refute html =~ "Nothing outstanding"
    assert html =~ "queued" or html =~ "Payout"

    payouts = Emakola.Payments.list_payouts_by_store!(store.id, authorize?: false)
    assert [payout] = payouts
    assert payout.basis == :allocations
    assert payout.amount == 12_000

    assert_enqueued(worker: PayoutWorker, args: %{"payout_id" => payout.id})

    page = Emakola.Accounts.list_platform_audit_logs!(authorize?: false, page: [limit: 200])
    assert Enum.any?(page.results, &(&1.action == :payout_approved and &1.actor_id == user.id))
  end
end
