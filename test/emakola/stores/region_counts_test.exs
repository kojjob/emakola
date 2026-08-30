defmodule Emakola.Stores.RegionCountsTest do
  @moduledoc """
  Active-store counts per Ghanaian region, for the directory's map picker.

  The map used to count the stores the page had paginated in so far and look
  them up under a slug the database never stores, so every region read
  "0 stores" however many shops were in it. These pin both halves: the count
  spans the whole directory, and it is keyed by the canonical region name
  `Store.region` actually holds.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores

  defp store_in!(region), do: Factory.create_store!(%{region: region})

  test "counts every active store in a region, not just a page of them" do
    for _ <- 1..15, do: store_in!("Greater Accra")
    store_in!("Ashanti")

    counts = Stores.region_counts()

    assert counts["Greater Accra"] == 15
    assert counts["Ashanti"] == 1
  end

  test "is keyed by the canonical name, the same string the region filter matches" do
    store_in!("Greater Accra")

    counts = Stores.region_counts()

    assert counts["Greater Accra"] == 1
    refute Map.has_key?(counts, "greater_accra")
  end

  test "a store with no region belongs to no region" do
    store_in!(nil)

    assert Stores.region_counts() == %{}
  end

  test "an inactive store is not counted" do
    store_in!("Volta")
    |> Ash.Changeset.for_update(:update_settings, %{active: false})
    |> Ash.update!(authorize?: false)

    assert Stores.region_counts() == %{}
  end
end
