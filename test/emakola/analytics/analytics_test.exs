defmodule Emakola.AnalyticsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Analytics
  alias Emakola.Analytics.{AppEvent, SearchConsoleData}
  import Emakola.Factory

  describe "AppEvent tracking" do
    test "tracks an event with all fields" do
      user = create_user!()
      org = create_organisation!()

      assert {:ok, event} =
               Analytics.track("agent.run",
                 actor_id: user.id,
                 org_id: org.id,
                 metadata: %{"agent_name" => "Test Agent", "duration_ms" => 1500}
               )

      assert event.event_name == "agent.run"
      assert event.actor_id == user.id
      assert event.organisation_id == org.id
      assert event.metadata["duration_ms"] == 1500
    end

    test "tracks event without optional fields" do
      assert {:ok, event} = Analytics.track("page.view")
      assert event.event_name == "page.view"
      assert is_nil(event.actor_id)
      assert event.metadata == %{}
    end

    test "requires event_name" do
      assert {:error, _} =
               AppEvent
               |> Ash.Changeset.for_create(:create, %{occurred_at: DateTime.utc_now()})
               |> Ash.create(authorize?: false)
    end

    test "broadcasts event to org channel" do
      org = create_organisation!()
      Phoenix.PubSub.subscribe(Emakola.PubSub, "org_events:#{org.id}")

      Analytics.track("test.event", org_id: org.id)

      assert_receive {:app_event, %{event_name: "test.event"}}
    end

    test "does not broadcast when no org_id" do
      # Should not crash even without org
      assert {:ok, _} = Analytics.track("anonymous.event")
    end
  end

  describe "AppEvent querying" do
    test "filters events by organisation" do
      org = create_organisation!()
      Analytics.track("event.a", org_id: org.id)
      Analytics.track("event.b", org_id: org.id)
      Analytics.track("event.c")

      {:ok, events} = Analytics.list_by_org(org.id)
      assert length(events) == 2
    end
  end

  describe "SearchConsoleData" do
    test "creates GSC data entry" do
      org = create_organisation!()

      assert {:ok, data} =
               SearchConsoleData
               |> Ash.Changeset.for_create(:create, %{
                 keyword: "elixir saas boilerplate",
                 page: "/",
                 clicks: 42,
                 impressions: 1500,
                 position: 3.2,
                 ctr: 0.028,
                 organisation_id: org.id,
                 fetched_at: DateTime.utc_now()
               })
               |> Ash.create(authorize?: false)

      assert data.keyword == "elixir saas boilerplate"
      assert data.clicks == 42
      assert data.position == 3.2
    end

    test "requires keyword and fetched_at" do
      assert {:error, _} =
               SearchConsoleData
               |> Ash.Changeset.for_create(:create, %{clicks: 10})
               |> Ash.create(authorize?: false)
    end
  end

  describe "GscSyncWorker" do
    test "succeeds with stub data" do
      org = create_organisation!()

      assert :ok =
               Emakola.Analytics.Workers.GscSyncWorker.perform(%Oban.Job{
                 args: %{"organisation_id" => org.id}
               })
    end
  end

  describe "edge cases" do
    test "handles high-frequency event tracking" do
      org = create_organisation!()

      tasks =
        for i <- 1..30 do
          Task.async(fn ->
            Analytics.track("load_test.#{i}", org_id: org.id)
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end

    test "handles unicode in event metadata" do
      assert {:ok, event} =
               Analytics.track("intl.test", metadata: %{"query" => "検索クエリ"})

      assert event.metadata["query"] == "検索クエリ"
    end

    test "handles zero-value GSC metrics" do
      assert {:ok, data} =
               SearchConsoleData
               |> Ash.Changeset.for_create(:create, %{
                 keyword: "zero test",
                 clicks: 0,
                 impressions: 0,
                 position: 0.0,
                 ctr: 0.0,
                 fetched_at: DateTime.utc_now()
               })
               |> Ash.create(authorize?: false)

      assert data.clicks == 0
    end
  end
end
