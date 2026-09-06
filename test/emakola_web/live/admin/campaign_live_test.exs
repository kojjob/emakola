defmodule EmakolaWeb.Admin.CampaignLiveTest do
  @moduledoc """
  The previous suite here asserted the fabrication itself — "displays campaign
  cards with sample data" — so it was deleted with the invented data it
  pinned. These test the real engine instead.
  """
  use EmakolaWeb.ConnCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Marketing.Campaigns

  setup do
    {merchant, store} = create_merchant_with_store!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "shows an empty state, and never invented figures", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

    assert html =~ "No campaigns yet"
    # Neither channel reports these without provider webhooks.
    refute html =~ "Opened"
    refute html =~ "Clicked"
  end

  test "names the audience before the merchant writes anything", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})
    create_customer!(ctx.store, %{phone: "+233202222222"})
    create_customer!(ctx.store, %{phone: nil})

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    # 2, not 3 — a customer with no phone cannot be reached, and the merchant
    # should know the real number before spending money.
    assert has_element?(view, "#campaign-audience-count", "2")
  end

  test "creates a campaign from the merchant's own input", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    view
    |> form("#campaign-form", campaign: %{name: "Weekend sale", body: "20% off this weekend."})
    |> render_submit()

    assert has_element?(view, "#campaigns", "Weekend sale")
    assert {:ok, [campaign]} = Campaigns.list(ctx.merchant, ctx.store.id)
    assert campaign.name == "Weekend sale"
    assert campaign.status == :draft
  end

  test "refuses an over-long message instead of charging for it", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    html =
      view
      |> form("#campaign-form",
        campaign: %{name: "Too long", body: String.duplicate("a", 481)}
      )
      |> render_submit()

    assert html =~ "too long"
    assert {:ok, []} = Campaigns.list(ctx.merchant, ctx.store.id)
  end

  test "sending queues the job rather than blocking the page", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})

    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Weekend sale",
        channel: :sms,
        body: "20% off."
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    view |> element("#send-campaign-#{campaign.id}") |> render_click()

    assert_enqueued(
      worker: Emakola.Marketing.CampaignSendWorker,
      args: %{"campaign_id" => campaign.id}
    )
  end

  test "a failed campaign offers Try again, and sending it queues the job", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})

    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Weekend sale",
        channel: :sms,
        body: "20% off."
      })

    campaign
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    assert has_element?(view, "#send-campaign-#{campaign.id}", "Try again")

    view |> element("#send-campaign-#{campaign.id}") |> render_click()

    assert_enqueued(
      worker: Emakola.Marketing.CampaignSendWorker,
      args: %{"campaign_id" => campaign.id}
    )
  end

  # The confirm dialog and the flash both read draft_audience_counts; if that
  # map only carries drafts, a retried campaign says "Send this to 0
  # customers?" while the audience is one.
  test "a failed campaign's retry names the real audience, not zero", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})

    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Weekend sale",
        channel: :sms,
        body: "20% off."
      })

    campaign
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    assert view
           |> element("#send-campaign-#{campaign.id}")
           |> render() =~ "1 customer"
  end

  test "another store's campaigns never appear", ctx do
    {other_merchant, other_store} = create_merchant_with_store!()

    {:ok, _theirs} =
      Campaigns.create(other_merchant, other_store.id, %{
        name: "Their private campaign",
        channel: :sms,
        body: "hello"
      })

    {:ok, _view, html} = live(ctx.conn, ~p"/admin/campaigns")

    refute html =~ "Their private campaign"
  end

  test "a campaign with 60 failed recipients shows 50 and says how many more", ctx do
    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Sale",
        channel: :sms,
        body: "Sale on."
      })

    for i <- 1..60 do
      customer =
        create_customer!(ctx.store, %{phone: "+23320000#{String.pad_leading("#{i}", 4, "0")}"})

      {:ok, recipient} =
        Emakola.Marketing.CampaignRecipient
        |> Ash.Changeset.for_create(:claim, %{
          campaign_id: campaign.id,
          customer_id: customer.id,
          phone: customer.phone
        })
        |> Ash.create(authorize?: false)

      recipient
      |> Ash.Changeset.for_update(:mark_failed, %{error: "boom"})
      |> Ash.update!(authorize?: false)
    end

    campaign
    |> Ash.Changeset.for_update(:record_result, %{sent_count: 0, failed_count: 60})
    |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    rendered = view |> element("#campaign-#{campaign.id}-failed") |> render()
    shown = Regex.scan(~r/\+2332000\d{4}/, rendered)
    assert length(shown) == 50
    assert rendered =~ "and 10 more"
  end
end
