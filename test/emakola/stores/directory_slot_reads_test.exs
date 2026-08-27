defmodule Emakola.Stores.DirectorySlotReadsTest do
  @moduledoc """
  The public read side of featuring: plain indexed column filters over the
  worker-maintained cache, plus the floor finally gating the staff picks.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Stores.Store

  defp put_slot!(store, slot, score) do
    store
    |> Ash.Changeset.for_update(:set_directory_standing, %{
      directory_eligible: true,
      directory_score: score,
      directory_slot: slot
    })
    |> Ash.update!(authorize?: false)
  end

  defp read!(action) do
    Store |> Ash.Query.for_read(action) |> Ash.read!(authorize?: false) |> Enum.map(& &1.name)
  end

  test "each slot read returns only its slot, best score first, name breaking ties" do
    create_store!(%{name: "Nobody"})
    create_store!(%{name: "Spot B"}) |> put_slot!(:spotlight, 500)
    create_store!(%{name: "Spot A"}) |> put_slot!(:spotlight, 500)
    create_store!(%{name: "Spot Top"}) |> put_slot!(:spotlight, 900)
    create_store!(%{name: "Riser"}) |> put_slot!(:rising, 100)

    assert read!(:list_spotlight) == ["Spot Top", "Spot A", "Spot B"]
    assert read!(:list_rising) == ["Riser"]
    assert read!(:list_promoted) == []
  end

  test "a suspended shop drops out of its slot read" do
    store = create_store!(%{name: "Falls Out"}) |> put_slot!(:spotlight, 800)

    store
    |> Ash.Changeset.for_update(:suspend, %{reason: "test"})
    |> Ash.update!(authorize?: false)

    assert read!(:list_spotlight) == []
  end

  test "the floor gates the staff picks: an ineligible featured shop leaves :list_featured" do
    eligible = create_store!(%{name: "Clean Pick", featured: true, featured_rank: 1})

    barred =
      create_store!(%{name: "Barred Pick", featured: true, featured_rank: 2})
      |> Ash.Changeset.for_update(:set_directory_standing, %{directory_eligible: false})
      |> Ash.update!(authorize?: false)

    names =
      Store
      |> Ash.Query.for_read(:list_featured, %{limit: 8})
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)

    assert "Clean Pick" in names
    refute "Barred Pick" in names
    _ = {eligible, barred}
  end
end
