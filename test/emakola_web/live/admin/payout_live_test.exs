defmodule EmakolaWeb.Admin.PayoutLiveTest do
  @moduledoc """
  Merchant payout onboarding page (SP1, path-independent slice): capture a
  mobile-money or bank payout destination. No subaccount/fee/money movement —
  saved details stay `verification_status: :unverified` behind an honest note.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.Workers.SubaccountCreationWorker
  alias Emakola.Stores
  alias EmakolaWeb.Helpers.Currency

  setup %{conn: conn} do
    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "a store with no payout account sees an empty form", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/admin/payouts")

    assert has_element?(view, "#payout-form")
    assert html =~ "Save payout details"
    refute html =~ "enables payouts in your region"
  end

  test "submitting mobile-money details persists them as unverified", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin/payouts")

    html =
      view
      |> element("#payout-form")
      |> render_submit(%{
        "payout" => %{
          "method" => "mobile_money",
          "provider" => "mtn",
          "number" => "0240000000",
          "account_name" => "Ama Trades"
        }
      })

    assert html =~ "enables payouts in your region"

    assert {:ok, account} = Stores.get_payout_account(store.id, authorize?: false)
    assert account.verification_status == :unverified
    assert account.payout_destination["method"] == "mobile_money"
    assert account.payout_destination["provider"] == "mtn"
    assert account.payout_destination["number"] == "0240000000"
    assert account.payout_destination["account_name"] == "Ama Trades"
  end

  test "saving payout details enqueues subaccount creation", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin/payouts")

    view
    |> element("#payout-form")
    |> render_submit(%{
      "payout" => %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0240000000",
        "account_name" => "Ama Trades"
      }
    })

    assert_enqueued(worker: SubaccountCreationWorker, args: %{"store_id" => store.id})
  end

  test "an existing account shows the update state and can be changed", %{
    conn: conn,
    store: store
  } do
    {:ok, _} =
      Stores.create_payout_account(
        %{
          store_id: store.id,
          payout_destination: %{
            "method" => "mobile_money",
            "provider" => "mtn",
            "number" => "0240000000",
            "account_name" => "Old Name"
          }
        },
        authorize?: false
      )

    {:ok, view, html} = live(conn, ~p"/admin/payouts")
    assert html =~ "Update payout details"
    assert html =~ "enables payouts in your region"

    view
    |> element("#payout-form")
    |> render_submit(%{
      "payout" => %{
        "method" => "bank",
        "bank_name" => "GCB Bank",
        "account_number" => "1234567890",
        "account_name" => "New Name"
      }
    })

    {:ok, account} = Stores.get_payout_account(store.id, authorize?: false)
    assert account.payout_destination["method"] == "bank"
    assert account.payout_destination["bank_name"] == "GCB Bank"
    assert account.payout_destination["account_number"] == "1234567890"
  end

  test "missing required fields shows an error and saves nothing", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin/payouts")

    html =
      view
      |> element("#payout-form")
      |> render_submit(%{
        "payout" => %{
          "method" => "mobile_money",
          "provider" => "mtn",
          "number" => "",
          "account_name" => ""
        }
      })

    assert html =~ "Please fill in every field"

    assert {:ok, nil} =
             Stores.get_payout_account(store.id, authorize?: false, not_found_error?: false)
  end

  # -- "Held by Buyer Protection" stat tile (TC-2 Task 11) --

  describe "buyer protection stat tile" do
    test "sums net only over the store's :held holds", %{conn: conn, store: store} do
      order1 = Emakola.Factory.create_order!(store)
      payment1 = Emakola.Factory.create_payment!(store, %{order_id: order1.id})
      create_protection_hold!(store, payment1, %{amount: 25_000, fee: 1_000, net: 24_000})

      order2 = Emakola.Factory.create_order!(store)
      payment2 = Emakola.Factory.create_payment!(store, %{order_id: order2.id})
      create_protection_hold!(store, payment2, %{amount: 10_000, fee: 1_000, net: 9_000})

      order3 = Emakola.Factory.create_order!(store)
      payment3 = Emakola.Factory.create_payment!(store, %{order_id: order3.id})

      released =
        create_protection_hold!(store, payment3, %{amount: 52_000, fee: 2_000, net: 50_000})

      released
      |> Ash.Changeset.for_update(:release, %{release_reason: :staff})
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      html = render_async(view)

      assert html =~ "Held by Buyer Protection"
      assert html =~ Currency.format_price(33_000, store.currency || "GHS")
      refute html =~ Currency.format_price(83_000, store.currency || "GHS")
    end

    test "shows zero when the store has no holds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      html = render_async(view)

      assert html =~ "Held by Buyer Protection"
      assert html =~ Currency.format_price(0, "GHS")
    end
  end

  # -- Accrued internal balance + MoMo nudge (Task 7) --

  describe "accrued internal balance + MoMo nudge" do
    test "payable balance with no destination shows the amount and the nudge", %{
      conn: conn,
      store: store
    } do
      payment = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, payment, %{amount: 12_000})

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      html = render_async(view)

      assert html =~ Currency.format_price(12_000, store.currency || "GHS")
      assert html =~ "waiting — add your mobile money number"
    end

    test "payable balance with a saved destination shows the amount but no nudge", %{
      conn: conn,
      store: store
    } do
      payment = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, payment, %{amount: 9_000})

      {:ok, _account} =
        Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{
              "method" => "mobile_money",
              "provider" => "mtn",
              "number" => "0240000000",
              "account_name" => "Ama Trades"
            }
          },
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      html = render_async(view)

      assert html =~ Currency.format_price(9_000, store.currency || "GHS")
      refute html =~ "waiting — add your mobile money number"
    end

    test "zero balance shows neither an accrued amount nor the nudge", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      html = render_async(view)

      assert html =~ Currency.format_price(0, store.currency || "GHS")
      refute html =~ "waiting — add your mobile money number"
    end
  end

  # -- Money picture: skeleton / failure / populated tiles / breakdown /
  # history (Task 2 — money-surfaces PR-1) --

  describe "money picture — loading" do
    test "while the money async is pending, tiles show a skeleton and no zero", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

      assert html =~ "payout-money-loading"
      refute html =~ "0.00"
      refute html =~ Currency.currency_symbol("GHS")
    end
  end

  describe "money picture — failure" do
    # Arranging a genuine `assign_async` failure through the full mount/live
    # pipeline isn't cheaply reachable here: every read `load_money/1` calls
    # (list_payable_internal_splits, held_net_total, outstanding_payments,
    # list_store_payouts) tolerates a nonexistent store_id by returning empty
    # results rather than raising — there's no FK-existence check on a
    # tenant-scoped filter — and the project has no stub/mock seam for these
    # plain Ash domain calls (Mox only covers gateway behaviours). Per the
    # brief's pre-authorized fallback, we render the failed-clause markup
    # directly with a hand-built `AsyncResult.failed/2` assign — the same
    # escape hatch Task 1 used for its unstampable-payout branch.
    test "a failed money load renders a dash treatment, never a zero" do
      assigns = %{
        account: nil,
        method: "mobile_money",
        currency: "GHS",
        payout_form: Phoenix.Component.to_form(%{"method" => "mobile_money"}, as: :payout),
        money: Phoenix.LiveView.AsyncResult.failed(Phoenix.LiveView.AsyncResult.loading(), :boom)
      }

      html =
        assigns
        |> EmakolaWeb.Admin.PayoutLive.render()
        |> rendered_to_string()

      assert html =~ "Couldn't load"
      assert html =~ "—"
      refute html =~ "0.00"
    end
  end

  describe "money picture — populated tiles" do
    test "accrued, held, and legacy amounts render under distinct test-ids", %{
      conn: conn,
      store: store
    } do
      accrued_payment = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, accrued_payment, %{amount: 12_000})

      order = Emakola.Factory.create_order!(store)
      held_payment = Emakola.Factory.create_payment!(store, %{order_id: order.id})
      create_protection_hold!(store, held_payment, %{amount: 25_000, fee: 1_000, net: 24_000})

      Emakola.Factory.create_payment!(store, %{amount: 30_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      render_async(view)

      assert view |> element("#payout-tile-accrued") |> render() =~
               Currency.format_price(12_000, store.currency || "GHS")

      assert view |> element("#payout-tile-held") |> render() =~
               Currency.format_price(24_000, store.currency || "GHS")

      assert view |> element("#payout-tile-legacy") |> render() =~
               Currency.format_price(30_000, store.currency || "GHS")
    end
  end

  describe "money picture — breakdown card" do
    test "lists per-role rows with counts from splits of two or more roles", %{
      conn: conn,
      store: store
    } do
      payment_a = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, payment_a, %{role: :merchant, amount: 5_000})

      payment_b = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, payment_b, %{role: :wholesaler, amount: 7_000})

      payment_c = Emakola.Factory.create_payment!(store)
      settled_internal_split!(store, payment_c, %{role: :wholesaler, amount: 9_000})

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      render_async(view)

      breakdown_html = view |> element("#payout-breakdown") |> render()

      assert breakdown_html =~ "Your sales"
      assert breakdown_html =~ "1 order"
      assert breakdown_html =~ "Resales of your stock"
      assert breakdown_html =~ "2 orders"
    end
  end

  describe "money picture — payout history" do
    test "shows a seeded payout with basis and status pills", %{conn: conn, store: store} do
      {:ok, payout} =
        Emakola.Payments.create_payout(
          %{
            store_id: store.id,
            amount: 42_000,
            currency: "GHS",
            transfer_reference: "PO-#{Ecto.UUID.generate()}",
            basis: :allocations
          },
          authorize?: false
        )

      {:ok, _payout} = Emakola.Payments.mark_payout_paid(payout, %{}, authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/payouts")
      render_async(view)

      history_html = view |> element("#payout-history") |> render()

      assert history_html =~ Currency.format_price(42_000, store.currency || "GHS")
      assert history_html =~ "Ledger"
      assert history_html =~ "Paid"
    end
  end

  describe "money picture — destination notice states" do
    test "no destination on file shows the add-details copy", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

      assert html =~ "Add your mobile money or bank details below"
      refute html =~ "enables payouts in your region"
    end

    test "a saved but unverified destination shows the saved-no-subaccount copy", %{
      conn: conn,
      store: store
    } do
      {:ok, _account} =
        Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{
              "method" => "mobile_money",
              "provider" => "mtn",
              "number" => "0240000000",
              "account_name" => "Ama Trades"
            }
          },
          authorize?: false
        )

      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

      assert html =~ "enables payouts in your region"
      refute html =~ "Your payout destination is verified"
    end

    test "a verified destination shows the verified copy", %{conn: conn, store: store} do
      {:ok, account} =
        Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{
              "method" => "mobile_money",
              "provider" => "mtn",
              "number" => "0240000000",
              "account_name" => "Ama Trades"
            }
          },
          authorize?: false
        )

      {:ok, _account} =
        Stores.record_payout_subaccount(account, %{subaccount_code: "SUB_123"}, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

      assert html =~ "Your payout destination is verified"
      refute html =~ "Payout details saved."
    end
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

  defp create_protection_hold!(store, payment, attrs) do
    default = %{
      store_id: store.id,
      payment_id: payment.id,
      order_id: payment.order_id
    }

    Emakola.Payments.ProtectionHold
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!(authorize?: false)
  end
end
