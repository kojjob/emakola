defmodule Emakola.Stores.DirectoryStandingTest do
  @moduledoc """
  The standing row is the featuring worker's ledger — score, eligibility,
  slot, and the staff overrides. Two boundaries live here and both are
  enforced at the data layer, not by discipline:

    * the worker's upsert may never touch the staff-owned override columns
      or the dark paid-placement seam;
    * nobody without the system escape hatch reads a standing at all —
      "disqualifiers: [:conduct]" and an override reason must never ride
      an anonymous storefront query.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Stores.DirectoryStanding

  defp record!(store, attrs \\ %{}) do
    DirectoryStanding
    |> Ash.Changeset.for_create(
      :record,
      Map.merge(
        %{
          store_id: store.id,
          eligible: true,
          disqualifiers: [],
          score: 640,
          score_breakdown: %{"fulfilment_volume" => 640},
          slot: :spotlight,
          computed_at: DateTime.utc_now()
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  test "one standing per store — the upsert identity holds" do
    store = create_store!()
    first = record!(store, %{score: 500})
    second = record!(store, %{score: 700})

    assert first.id == second.id
    assert second.score == 700
    assert 1 == DirectoryStanding |> Ash.read!(authorize?: false) |> length()
  end

  test "the worker's upsert preserves staff overrides and the paid seam" do
    store = create_store!()
    standing = record!(store)

    standing
    |> Ash.Changeset.for_update(:override, %{
      override_slot: :rising,
      override_excluded: false,
      override_reason: "campaign pin",
      override_until: DateTime.add(DateTime.utc_now(), 30, :day)
    })
    |> Ash.update!(authorize?: false)

    # The nightly run recomputes — and must not clobber what staff set.
    rerun = record!(store, %{score: 120, slot: nil, eligible: false, disqualifiers: [:abandoned]})

    assert rerun.score == 120
    assert rerun.override_slot == :rising
    assert rerun.override_reason == "campaign pin"
    assert rerun.paid_placement_weight == 0
  end

  test "nobody without the system escape hatch reads a standing" do
    store = create_store!()
    record!(store, %{eligible: false, disqualifiers: [:conduct]})

    merchant = create_merchant!()
    create_store_membership!(merchant, store, :owner)

    for actor <- [nil, merchant] do
      result = DirectoryStanding |> Ash.Query.for_read(:read) |> Ash.read(actor: actor)
      assert {:error, %Ash.Error.Forbidden{}} = result
    end
  end

  test "a merchant cannot write their own standing either" do
    store = create_store!()
    merchant = create_merchant!()
    create_store_membership!(merchant, store, :owner)

    result =
      DirectoryStanding
      |> Ash.Changeset.for_create(:record, %{
        store_id: store.id,
        eligible: true,
        disqualifiers: [],
        score: 1000,
        score_breakdown: %{},
        slot: :spotlight,
        computed_at: DateTime.utc_now()
      })
      |> Ash.create(actor: merchant)

    assert {:error, %Ash.Error.Forbidden{}} = result
  end

  test "a fresh store is directory-eligible before the worker has ever run — fail-open" do
    store = create_store!()

    assert store.directory_eligible == true
    assert is_nil(store.directory_score)
    assert is_nil(store.directory_slot)
  end
end
