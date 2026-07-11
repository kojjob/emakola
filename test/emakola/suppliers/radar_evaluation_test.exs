defmodule Emakola.Suppliers.RadarEvaluationTest do
  @moduledoc """
  Income-OS Phase C exit criterion: prove the radar beats a popularity-only
  baseline in fulfilled sales without increasing refunds. This harness splits
  stores into deterministic arms and aggregates outcomes from the existing
  conversion ledger; the live run itself needs real pilot traffic.
  """

  use ExUnit.Case, async: true

  alias Emakola.Suppliers.RadarEvaluation

  describe "arm/1" do
    test "is deterministic for a store and reaches both arms across stores" do
      store_id = Ecto.UUID.generate()
      assert RadarEvaluation.arm(store_id) == RadarEvaluation.arm(store_id)

      arms =
        Stream.repeatedly(fn -> Ecto.UUID.generate() end)
        |> Enum.take(64)
        |> Enum.map(&RadarEvaluation.arm/1)
        |> Enum.uniq()
        |> Enum.sort()

      assert arms == [:popularity, :radar]
    end
  end

  describe "rank/2" do
    setup do
      # Radar's blended order puts the high-demand-signal entry first even
      # though it has fewer orders; pure popularity must invert that.
      entries = [
        %{title: "High views", views: 100, searches: 5, orders: 1, fulfilled: 1, refunded: 0},
        %{title: "High orders", views: 0, searches: 0, orders: 9, fulfilled: 5, refunded: 0}
      ]

      %{entries: entries}
    end

    test "the radar arm preserves the radar's blended order", %{entries: entries} do
      assert RadarEvaluation.rank(entries, store_for(:radar)) == entries
    end

    test "the popularity arm ranks purely by order count", %{entries: entries} do
      ranked = RadarEvaluation.rank(entries, store_for(:popularity))
      assert Enum.map(ranked, & &1.title) == ["High orders", "High views"]
    end
  end

  describe "summarize/1" do
    test "aggregates orders, fulfillment, refunds, and fulfilled revenue per arm" do
      radar_store = store_for(:radar)
      popularity_store = store_for(:popularity)

      rows = [
        %{store_id: radar_store, revenue: 5_000, delivered?: true, refunded?: false},
        %{store_id: radar_store, revenue: 3_000, delivered?: false, refunded?: true},
        %{store_id: popularity_store, revenue: 2_000, delivered?: true, refunded?: false}
      ]

      report = RadarEvaluation.summarize(rows)

      assert report.radar == %{
               stores: 1,
               orders: 2,
               fulfilled: 1,
               refunded: 1,
               fulfilled_revenue: 5_000
             }

      assert report.popularity == %{
               stores: 1,
               orders: 1,
               fulfilled: 1,
               refunded: 0,
               fulfilled_revenue: 2_000
             }
    end

    test "an empty ledger produces zeroed arms" do
      assert %{radar: %{orders: 0, fulfilled_revenue: 0}, popularity: %{orders: 0}} =
               RadarEvaluation.summarize([])
    end
  end

  defp store_for(arm) do
    Stream.repeatedly(fn -> Ecto.UUID.generate() end)
    |> Enum.find(&(RadarEvaluation.arm(&1) == arm))
  end
end
