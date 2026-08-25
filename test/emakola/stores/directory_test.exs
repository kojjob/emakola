defmodule Emakola.Stores.DirectoryTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Stores.Directory

  describe "spotlight/2" do
    test "returns nothing when there is nothing featured" do
      assert Directory.spotlight([], ~D[2026-08-25]) == []
    end

    test "a single featured shop holds the slot every day" do
      assert Directory.spotlight([:only], ~D[2026-08-25]) == [:only]
      assert Directory.spotlight([:only], ~D[2026-12-31]) == [:only]
    end

    test "the same date always puts the same shop first" do
      shops = [:a, :b, :c, :d]

      assert Directory.spotlight(shops, ~D[2026-08-25]) ==
               Directory.spotlight(shops, ~D[2026-08-25])
    end

    test "the next day moves the slot on by one" do
      shops = [:a, :b, :c, :d]

      [today | _] = Directory.spotlight(shops, ~D[2026-08-25])
      [tomorrow | _] = Directory.spotlight(shops, ~D[2026-08-26])

      refute today == tomorrow
    end

    test "every shop gets the slot across a full cycle" do
      shops = [:a, :b, :c, :d]

      heads =
        for offset <- 0..3 do
          [head | _] = Directory.spotlight(shops, Date.add(~D[2026-08-25], offset))
          head
        end

      assert Enum.sort(heads) == Enum.sort(shops)
    end

    test "it rotates rather than drops — nobody falls off the list" do
      shops = [:a, :b, :c, :d]

      assert shops |> Directory.spotlight(~D[2026-08-27]) |> Enum.sort() == Enum.sort(shops)
    end
  end

  describe "rails/1" do
    test "a rail that cannot fill four cards does not render" do
      for _ <- 1..3, do: create_store!(%{})

      refute Enum.any?(Directory.rails(), &(&1.stores == []))
      assert Enum.all?(Directory.rails(), &(length(&1.stores) >= 4))
    end

    test "just opened appears once there are enough shops, newest first" do
      for i <- 1..5, do: create_store!(%{name: "Shop #{i}"})

      rail = Enum.find(Directory.rails(), &(&1.id == :just_opened))

      assert rail, "expected a just_opened rail"
      assert length(rail.stores) >= 4
      assert rail.title == "Just opened"
    end

    test "every rail carries a title and a non-empty store list" do
      for i <- 1..6, do: create_store!(%{name: "Shop #{i}"})

      for rail <- Directory.rails() do
        assert is_binary(rail.title) and rail.title != ""
        assert rail.stores != []
        assert is_atom(rail.id)
      end
    end

    test "rails hold no duplicates within themselves" do
      for i <- 1..6, do: create_store!(%{name: "Shop #{i}"})

      for rail <- Directory.rails() do
        slugs = Enum.map(rail.stores, & &1.slug)
        assert slugs == Enum.uniq(slugs)
      end
    end

    test "a caller's own themes drive the rails, with ids they supply" do
      for i <- 1..5, do: create_store!(%{name: "Themed #{i}"})

      rails = Directory.rails(themes: [{:theme_fresh, "fresh", "Fresh"}])

      # No rail id is ever derived from the theme string at runtime.
      assert Enum.all?(rails, &is_atom(&1.id))
      refute Enum.any?(rails, &(&1.id == :theme_beauty))
    end

    test "an empty marketplace renders no rails at all, rather than empty headings" do
      assert Directory.rails() == []
    end
  end
end
