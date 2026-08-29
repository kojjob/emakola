defmodule Emakola.Analytics.GscDedupTest do
  @moduledoc """
  Search Console is queried for a ROLLING 28-day window aggregated by
  (query, page) — there is no date dimension in the response. So each nightly
  run returns the same rows with a fresh `fetched_at`, and creating them
  blindly stacks one copy per night.

  Production had the same keyword repeated up to twelve times before this.
  Nothing read the table yet, so nothing was visibly wrong — it would simply
  have inflated the first trend anyone tried to read off it.
  """
  use Emakola.DataCase, async: false

  alias Emakola.Analytics.SearchConsoleData
  alias Emakola.Analytics.Workers.GscSyncWorker

  defp rows(overrides \\ %{}) do
    [
      Map.merge(
        %{
          keyword: "sell online ghana",
          page: "https://makola.io/blog/how-to-sell-online-in-ghana",
          clicks: 0,
          impressions: 13,
          position: 24.6,
          ctr: 0.0,
          fetched_at: DateTime.truncate(DateTime.utc_now(), :second)
        },
        overrides
      )
    ]
  end

  defp sync_returning(rows) do
    Application.put_env(:emakola, :gsc_fetcher, __MODULE__.StubFetcher)
    Application.put_env(:emakola, :stub_gsc_rows, rows)
    on_exit(fn -> Application.delete_env(:emakola, :stub_gsc_rows) end)
    GscSyncWorker.perform(%Oban.Job{args: %{}})
  end

  defp stored do
    {:ok, all} = Ash.read(SearchConsoleData, authorize?: false)
    all
  end

  describe "repeated syncs" do
    test "keep exactly one row per keyword and page" do
      assert :ok = sync_returning(rows())
      assert :ok = sync_returning(rows())
      assert :ok = sync_returning(rows())

      assert length(stored()) == 1
    end

    test "refresh the metrics rather than stacking a stale copy" do
      assert :ok = sync_returning(rows())
      assert :ok = sync_returning(rows(%{impressions: 47, clicks: 3, position: 8.2}))

      assert [row] = stored()
      assert row.impressions == 47
      assert row.clicks == 3
      assert row.position == 8.2
    end

    test "move fetched_at forward so staleness is still visible" do
      assert :ok = sync_returning(rows(%{fetched_at: ~U[2026-08-01 00:00:00Z]}))
      [first] = stored()

      assert :ok = sync_returning(rows(%{fetched_at: ~U[2026-08-24 00:00:00Z]}))
      [second] = stored()

      assert DateTime.compare(second.fetched_at, first.fetched_at) == :gt
    end
  end

  describe "rows that are genuinely different" do
    test "the same keyword on a different page is kept separately" do
      assert :ok = sync_returning(rows())
      assert :ok = sync_returning(rows(%{page: "https://makola.io/pricing"}))

      assert length(stored()) == 2
    end

    test "a different keyword on the same page is kept separately" do
      assert :ok = sync_returning(rows())
      assert :ok = sync_returning(rows(%{keyword: "momo payments online"}))

      assert length(stored()) == 2
    end

    # The trap: a NULL page is what Postgres treats as distinct from every
    # other NULL, so a plain unique index would let these stack forever.
    test "rows with no page still dedupe against each other" do
      assert :ok = sync_returning(rows(%{page: nil}))
      assert :ok = sync_returning(rows(%{page: nil}))

      assert length(stored()) == 1
    end
  end

  defmodule StubFetcher do
    @moduledoc false
    def fetch(_org_id), do: {:ok, Application.get_env(:emakola, :stub_gsc_rows, [])}
  end
end
