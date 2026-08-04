defmodule EmakolaWeb.Admin.CampaignLiveTest do
  @moduledoc """
  LiveView tests for the admin campaigns page.
  Tests campaign listing, KPI cards, quick start templates, modals, and auth redirect.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    # Create merchant, store, and authenticate
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "CampaignLive.Index" do
    test "renders campaigns page with header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Campaigns"
      assert html =~ "Engage customers with targeted messages"
    end

    test "displays KPI cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Total Campaigns"
      assert html =~ "Messages Sent"
      assert html =~ "Avg. Open Rate"
      assert html =~ "2,847"
      assert html =~ "72.4%"
    end

    test "displays campaign cards with sample data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Welcome Series"
      assert html =~ "Abandoned Cart Recovery"
      assert html =~ "Easter Sale Announcement"
      assert html =~ "Re-engagement"
    end

    test "displays campaign status badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Active"
      assert html =~ "Scheduled"
      assert html =~ "Draft"
    end

    test "displays campaign channel labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "WhatsApp"
      assert html =~ "WhatsApp + SMS"
      assert html =~ "SMS"
    end

    test "displays campaign performance chart section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Campaign Performance"
      assert html =~ "Last 6 campaigns"
    end

    test "displays quick start templates", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Quick Start Templates"
      assert html =~ "Abandoned Cart"
      assert html =~ "Welcome Series"
      assert html =~ "Product Launch"
    end

    test "renders create campaign button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Create Campaign"
    end

    test "renders create campaign modal markup", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      # The modal is always in the DOM (hidden by default)
      assert html =~ "create-campaign-modal"
      assert html =~ "Campaign Name"
      assert html =~ "Channel"
    end

    test "handles save_campaign event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      html =
        view
        |> element("#create-campaign-form")
        |> render_submit(%{
          "campaign" => %{
            "name" => "Test Campaign",
            "channel" => "whatsapp",
            "description" => "Test"
          }
        })

      assert html =~ "Campaign created successfully!"
    end

    test "displays campaign stats in cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      # Welcome Series stats
      assert html =~ "456"
      assert html =~ "89%"
      assert html =~ "34%"

      # Abandoned Cart Recovery stats
      assert html =~ "1,247"
      assert html =~ "18%"
    end

    test "displays delete button for each campaign", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      assert has_element?(view, "button[aria-label='Delete Welcome Series']")
      assert has_element?(view, "button[aria-label='Delete Re-engagement']")
    end

    test "renders delete confirmation modal markup", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "delete-campaign-modal"
      assert html =~ "Delete Campaign"
    end

    test "handles delete_campaign event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      html = render_click(view, "delete_campaign", %{})

      assert html =~ "Campaign deleted."
    end

    test "sets page title to Campaigns", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

      assert html =~ "Campaigns"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/campaigns")
    end
  end

  # ── Test Helpers ──

  defp create_authenticated_merchant! do
    store =
      Emakola.Stores.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!(authorize?: false)

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
