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
    {:ok, _view, html} = live(conn, ~p"/admin/payouts")

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

      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

      assert html =~ "Held by Buyer Protection"
      assert html =~ Currency.format_price(33_000, store.currency || "GHS")
      refute html =~ Currency.format_price(83_000, store.currency || "GHS")
    end

    test "shows zero when the store has no holds", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/payouts")

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
