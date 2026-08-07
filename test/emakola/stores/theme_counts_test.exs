defmodule Emakola.Stores.ThemeCountsTest do
  @moduledoc """
  Active-store counts per theme, for the marketplace directory's filter
  chips — one grouped query instead of one COUNT per theme.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores

  defp themed_store!(theme) do
    Factory.create_store!(%{theme_config: %{"theme" => theme}})
  end

  test "counts active stores per theme" do
    themed_store!("atelier")
    themed_store!("atelier")
    themed_store!("bold")

    counts = Stores.theme_counts()

    assert counts["atelier"] == 2
    assert counts["bold"] == 1
  end

  test "a store with no theme_config falls back to market" do
    Factory.create_store!()

    counts = Stores.theme_counts()

    assert counts["market"] == 1
  end

  test "an inactive store is not counted" do
    themed_store!("bold")
    |> Ash.Changeset.for_update(:update_settings, %{active: false})
    |> Ash.update!(authorize?: false)

    assert Stores.theme_counts() == %{}
  end

  test "a suspended store is not counted" do
    store = themed_store!("bold")

    store
    |> Ash.Changeset.for_update(:suspend, %{reason: "policy"})
    |> Ash.update!(authorize?: false)

    assert Stores.theme_counts() == %{}
  end

  test "is empty with no stores" do
    assert Stores.theme_counts() == %{}
  end
end
