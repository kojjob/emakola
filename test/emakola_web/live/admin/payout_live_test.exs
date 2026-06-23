defmodule EmakolaWeb.Admin.PayoutLiveTest do
  @moduledoc """
  Merchant payout onboarding page (SP1, path-independent slice): capture a
  mobile-money or bank payout destination. No subaccount/fee/money movement —
  saved details stay `verification_status: :unverified` behind an honest note.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Stores

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
end
