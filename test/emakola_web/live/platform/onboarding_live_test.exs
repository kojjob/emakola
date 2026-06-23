defmodule EmakolaWeb.Platform.OnboardingLiveTest do
  @moduledoc """
  Platform onboarding-health page: funnel + per-store table, permission gating,
  and the incomplete-only filter.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Stores

  test "staff without :manage_merchants is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/onboarding")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "renders the funnel and a store row", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      Factory.create_product!(store)

      {:ok, _view, html} = live(conn, ~p"/platform/onboarding")

      assert html =~ "Onboarding"
      assert html =~ "Kente Kingdom"
      assert html =~ "Products"
    end

    test "the incomplete-only filter hides fully-onboarded stores", %{conn: conn} do
      full = Factory.create_store!(%{name: "Complete Co"})
      Factory.create_product!(full)
      Factory.create_order!(full)

      {:ok, _} =
        Stores.create_payout_account(
          %{store_id: full.id, payout_destination: %{"method" => "mobile_money"}},
          authorize?: false
        )

      {:ok, v} =
        Stores.submit_store_verification(
          %{
            store_id: full.id,
            business_name: "A",
            id_type: :ghana_card,
            id_number: "X",
            id_document_key: "k"
          },
          authorize?: false
        )

      {:ok, _} = Stores.approve_store_verification(v, authorize?: false)

      {:ok, view, html} = live(conn, ~p"/platform/onboarding")
      assert html =~ "Complete Co"

      html = view |> element("button[phx-click='toggle_incomplete']") |> render_click()
      refute html =~ "Complete Co"
    end
  end
end
