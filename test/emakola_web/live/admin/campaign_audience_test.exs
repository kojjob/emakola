defmodule EmakolaWeb.Admin.CampaignAudienceTest do
  @moduledoc """
  Every SMS went to everyone. A campaign now names who it is for, the reach
  count follows the choice, and the send worker uses the same answer.
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

    twice = create_customer!(store, %{phone: "+233201111111"})
    once = create_customer!(store, %{phone: "+233202222222"})

    for _ <- 1..2,
        do:
          create_order!(store, %{
            subtotal: 100,
            total: 100,
            status: :confirmed,
            customer_id: twice.id
          })

    create_order!(store, %{subtotal: 100, total: 100, status: :confirmed, customer_id: once.id})

    %{conn: conn, merchant: merchant, store: store, twice: twice}
  end

  test "choosing a segment changes the reach count", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    assert has_element?(view, "#campaign-audience-count", "2")

    view
    |> form("#campaign-form", campaign: %{audience: "bought_again"})
    |> render_change()

    assert has_element?(view, "#campaign-audience-count", "1")
  end

  test "the campaign remembers its audience and the worker sends to it", ctx do
    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Thank you",
        channel: :sms,
        body: "Thank you for coming back.",
        audience: :bought_again
      })

    assert campaign.audience == :bought_again

    {:ok, customers} = Campaigns.reachable_customers(ctx.store.id, :bought_again)
    assert Enum.map(customers, & &1.id) == [ctx.twice.id]
  end

  test "another store's campaign cannot be sent from here", ctx do
    {other_merchant, other_store} = create_merchant_with_store!()

    {:ok, theirs} =
      Campaigns.create(other_merchant, other_store.id, %{
        name: "Theirs",
        channel: :sms,
        body: "hi"
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    render_click(view, "send", %{"id" => theirs.id})

    refute_enqueued(
      worker: Emakola.Marketing.CampaignSendWorker,
      args: %{"campaign_id" => theirs.id}
    )
  end

  test "a crafted id survives instead of crashing the page", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    render_click(view, "send", %{"id" => ["x"]})

    assert has_element?(view, "#campaign-form")
  end

  test "a crafted map for name/body survives create instead of crashing", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    view
    |> element("#campaign-form")
    |> render_submit(%{"campaign" => %{"name" => %{"x" => "y"}, "body" => "hi"}})

    assert has_element?(view, "#campaign-form")
    assert {:ok, []} = Campaigns.list(ctx.merchant, ctx.store.id)
  end

  test "a second click on the same campaign enqueues nothing new", ctx do
    {:ok, campaign} =
      Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Weekend sale",
        channel: :sms,
        body: "20% off."
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/campaigns")

    view |> element("#send-campaign-#{campaign.id}") |> render_click()
    render_click(view, "send", %{"id" => campaign.id})

    assert length(all_enqueued(worker: Emakola.Marketing.CampaignSendWorker)) == 1
  end

  describe "with no store yet" do
    setup do
      merchant = create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn}
    end

    test "send survives a nil store instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      render_click(view, "send", %{"id" => Ash.UUID.generate()})

      assert has_element?(view, "#campaign-form")
    end

    test "changing the audience survives a nil store instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      view
      |> form("#campaign-form", campaign: %{audience: "bought_again"})
      |> render_change()

      assert has_element?(view, "#campaign-audience-count", "0")
    end

    test "creating a campaign survives a nil store instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/campaigns")

      html =
        view
        |> form("#campaign-form", campaign: %{name: "Test", body: "hi"})
        |> render_submit()

      assert html =~ "Create your store first."
    end
  end
end
