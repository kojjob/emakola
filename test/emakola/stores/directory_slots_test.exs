defmodule Emakola.Stores.DirectorySlotsTest do
  @moduledoc """
  Slot assignment: pure, deterministic, and honest about scarcity. These
  tests pin the precedence order (exclusion beats everything, a live pin
  beats the computed answer, an expired pin beats nothing) and the
  starvation rules — the hero backfills, the growth rail hides rather
  than lies.
  """
  use ExUnit.Case, async: true

  alias Emakola.Stores.DirectorySlots

  @now ~U[2026-08-27 12:00:00.000000Z]

  defp entry(overrides) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Shop #{System.unique_integer([:positive])}",
        eligible?: true,
        score: 500,
        young?: false,
        staff_pick?: false,
        override_slot: nil,
        override_excluded: false,
        override_until: nil,
        paid_weight: 0,
        paid_until: nil
      },
      overrides
    )
  end

  defp names(slots, key), do: slots |> Map.fetch!(key) |> Enum.map(& &1.name)

  test "an ineligible shop lands in no slot, whatever its score" do
    slots =
      DirectorySlots.assign(
        [
          entry(%{name: "Saint", score: 900}),
          entry(%{name: "Rotten", score: 1000, eligible?: false}),
          entry(%{name: "Rotten Pick", score: 1000, eligible?: false, staff_pick?: true}),
          entry(%{name: "Rotten Young", score: 1000, eligible?: false, young?: true})
        ],
        @now
      )

    all = Enum.flat_map([:spotlight, :rising, :editors_pick, :promoted], &names(slots, &1))
    refute Enum.any?(all, &String.starts_with?(&1, "Rotten"))
  end

  test "exclusion beats a top score AND a live pin" do
    slots =
      DirectorySlots.assign(
        [
          entry(%{name: "Kept", score: 400}),
          entry(%{
            name: "Banished",
            score: 1000,
            override_excluded: true,
            override_slot: :spotlight,
            override_until: DateTime.add(@now, 10, :day)
          })
        ],
        @now
      )

    refute "Banished" in Enum.flat_map([:spotlight, :rising, :editors_pick], &names(slots, &1))
  end

  test "a live pin beats the computed slot; an expired one does not" do
    slots =
      DirectorySlots.assign(
        [
          entry(%{
            name: "Pinned",
            score: 1,
            override_slot: :spotlight,
            override_until: DateTime.add(@now, 5, :day)
          }),
          entry(%{
            name: "Lapsed",
            score: 2,
            young?: false,
            override_slot: :spotlight,
            override_until: DateTime.add(@now, -1, :day)
          }),
          entry(%{name: "Earned", score: 900})
        ],
        @now
      )

    assert "Pinned" in names(slots, :spotlight)
    assert "Earned" in names(slots, :spotlight)
    # The lapsed pin falls back to whatever it earns — here, ordinary spotlight
    # membership by score, not the pinned head position.
    assert names(slots, :spotlight) |> List.first() != "Lapsed"
  end

  test "a pin with no expiry set counts as live" do
    slots =
      DirectorySlots.assign(
        [entry(%{name: "Open Pin", score: 1, override_slot: :rising, override_until: nil})],
        @now
      )

    assert "Open Pin" in names(slots, :rising)
  end

  test "promoted is always empty today — the seam's guard" do
    slots =
      DirectorySlots.assign(
        [entry(%{name: "Would Pay", score: 900, paid_weight: 50})],
        @now
      )

    assert names(slots, :promoted) == []
  end

  test "starvation: rising hides below four rather than lying about what is new" do
    young = for i <- 1..3, do: entry(%{name: "Young #{i}", young?: true, score: 100})

    slots = DirectorySlots.assign(young ++ [entry(%{name: "Old", score: 600})], @now)

    assert names(slots, :rising) == []
  end

  test "starvation: four young shops fill the rising rail" do
    young = for i <- 1..4, do: entry(%{name: "Young #{i}", young?: true, score: 100})

    slots = DirectorySlots.assign(young, @now)

    assert length(names(slots, :rising)) == 4
  end

  test "starvation: the spotlight never hides while anyone is eligible" do
    slots = DirectorySlots.assign([entry(%{name: "Lone", score: 10})], @now)

    assert names(slots, :spotlight) == ["Lone"]
  end

  test "editors picks hide below three" do
    picks = for i <- 1..2, do: entry(%{name: "Pick #{i}", staff_pick?: true})

    slots = DirectorySlots.assign(picks, @now)

    assert names(slots, :editors_pick) == []
    # They are still eligible shops — they fall back into the spotlight pool.
    assert Enum.all?(1..2, fn i -> "Pick #{i}" in names(slots, :spotlight) end)
  end

  test "no shop ever appears in two slots" do
    entries = [
      entry(%{name: "A", score: 900, staff_pick?: true}),
      entry(%{name: "B", score: 800, staff_pick?: true}),
      entry(%{name: "C", score: 700, staff_pick?: true}),
      entry(%{name: "D", score: 600, young?: true}),
      entry(%{name: "E", score: 500, young?: true}),
      entry(%{name: "F", score: 400, young?: true}),
      entry(%{name: "G", score: 300, young?: true})
    ]

    slots = DirectorySlots.assign(entries, @now)
    all = Enum.flat_map([:spotlight, :rising, :editors_pick, :promoted], &names(slots, &1))

    assert all == Enum.uniq(all)
  end

  test "ordering is deterministic on a score tie — name breaks it" do
    slots =
      DirectorySlots.assign(
        [entry(%{name: "Zebra", score: 500}), entry(%{name: "Aardvark", score: 500})],
        @now
      )

    assert names(slots, :spotlight) == ["Aardvark", "Zebra"]
  end
end
