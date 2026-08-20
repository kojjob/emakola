defmodule Emakola.Stores.FeaturedRankingTest do
  @moduledoc """
  Featured-store ranking: featuring appends at the end of the order,
  unfeaturing compacts the remaining ranks to 1..n, and move/2 swaps a
  store with its neighbour (normalizing legacy gapped or duplicate
  ranks first). Order is rank asc with unranked featured stores last.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores.FeaturedRanking

  defp rank!(store) do
    Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured_rank
  end

  defp featured?(store) do
    Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).featured
  end

  describe "feature/1" do
    test "first featured store gets rank 1" do
      store = Factory.create_store!(featured: false)

      assert {:ok, _} = FeaturedRanking.feature(store)

      assert featured?(store)
      assert rank!(store) == 1
    end

    test "a newly featured store is appended after existing ones" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: false)

      assert {:ok, _} = FeaturedRanking.feature(second)

      assert rank!(first) == 1
      assert rank!(second) == 2
    end
  end

  describe "unfeature/1" do
    test "clears the flag and rank, compacting the others" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: true, featured_rank: 2)
      third = Factory.create_store!(featured: true, featured_rank: 3)

      assert {:ok, _} = FeaturedRanking.unfeature(second)

      refute featured?(second)
      assert rank!(second) == nil
      assert rank!(first) == 1
      assert rank!(third) == 2
    end
  end

  describe "move/2" do
    test "up swaps a store with the one ranked above it" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: true, featured_rank: 2)

      assert {:ok, _} = FeaturedRanking.move(second, :up)

      assert rank!(second) == 1
      assert rank!(first) == 2
    end

    test "down swaps a store with the one ranked below it" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: true, featured_rank: 2)

      assert {:ok, _} = FeaturedRanking.move(first, :down)

      assert rank!(first) == 2
      assert rank!(second) == 1
    end

    test "up at the top and down at the bottom are no-ops" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: true, featured_rank: 2)

      assert {:ok, _} = FeaturedRanking.move(first, :up)
      assert {:ok, _} = FeaturedRanking.move(second, :down)

      assert rank!(first) == 1
      assert rank!(second) == 2
    end

    test "normalizes gapped and unranked stores before swapping" do
      # Legacy data: gapped ranks and an unranked featured store (sorts last).
      gapped = Factory.create_store!(featured: true, featured_rank: 5)
      unranked = Factory.create_store!(featured: true, featured_rank: nil)

      assert {:ok, _} = FeaturedRanking.move(unranked, :up)

      assert rank!(unranked) == 1
      assert rank!(gapped) == 2
    end
  end

  describe "position/1" do
    test "returns the 1-based position and featured total" do
      first = Factory.create_store!(featured: true, featured_rank: 1)
      second = Factory.create_store!(featured: true, featured_rank: 2)
      _unfeatured = Factory.create_store!(featured: false)

      assert FeaturedRanking.position(first) == {1, 2}
      assert FeaturedRanking.position(second) == {2, 2}
    end
  end
end
