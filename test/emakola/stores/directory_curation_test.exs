defmodule Emakola.Stores.DirectoryCurationTest do
  @moduledoc """
  Staff overrides on featuring: immediate on the public read, audited with
  the store id the timeline filters on, and never accepted without a
  written reason — the reason is what makes the audit log worth reading
  six months later.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Stores.DirectoryCuration
  alias Emakola.Stores.DirectoryStanding
  alias Emakola.Stores.Store

  setup do
    store = create_store!(%{name: "Curated Shop"})

    standing =
      DirectoryStanding
      |> Ash.Changeset.for_create(:record, %{
        store_id: store.id,
        eligible: true,
        disqualifiers: [],
        score: 700,
        score_breakdown: %{},
        slot: :spotlight,
        computed_at: DateTime.utc_now()
      })
      |> Ash.create!(authorize?: false)

    store
    |> Ash.Changeset.for_update(:set_directory_standing, %{
      directory_eligible: true,
      directory_score: 700,
      directory_slot: :spotlight
    })
    |> Ash.update!(authorize?: false)

    %{store: store, standing: standing, staff: create_platform_owner!()}
  end

  defp reload_store(store), do: Ash.get!(Store, store.id, authorize?: false)

  defp audit_rows(store) do
    Emakola.Accounts.PlatformAuditLog
    |> Ash.Query.for_read(:list_for_store, %{store_id: store.id})
    |> Ash.read!(authorize?: false)
  end

  test "excluding a shop empties its slot immediately, without a worker run", ctx do
    assert {:ok, _} =
             DirectoryCuration.set_excluded(
               ctx.standing,
               true,
               "counterfeit complaints",
               ctx.staff
             )

    assert is_nil(reload_store(ctx.store).directory_slot)
    refute reload_store(ctx.store).directory_eligible == false or true == false

    standing = Ash.reload!(ctx.standing, authorize?: false)
    assert standing.override_excluded
    assert standing.override_reason == "counterfeit complaints"
  end

  test "pinning a shop moves its cached slot immediately", ctx do
    assert {:ok, _} =
             DirectoryCuration.override_slot(ctx.standing, :rising, "launch week", ctx.staff)

    assert reload_store(ctx.store).directory_slot == :rising
  end

  test "clearing a pin returns the shop to its computed slot", ctx do
    {:ok, _} = DirectoryCuration.override_slot(ctx.standing, :rising, "launch week", ctx.staff)
    standing = Ash.reload!(ctx.standing, authorize?: false)

    assert {:ok, _} = DirectoryCuration.override_slot(standing, nil, "week over", ctx.staff)

    assert reload_store(ctx.store).directory_slot == :spotlight
    assert is_nil(Ash.reload!(ctx.standing, authorize?: false).override_slot)
  end

  test "a blank reason is refused — both operations", ctx do
    assert {:error, _} = DirectoryCuration.set_excluded(ctx.standing, true, "   ", ctx.staff)
    assert {:error, _} = DirectoryCuration.override_slot(ctx.standing, :rising, "", ctx.staff)
  end

  test "every curation write lands in the store's audit timeline", ctx do
    {:ok, _} = DirectoryCuration.override_slot(ctx.standing, :rising, "launch week", ctx.staff)

    {:ok, _} =
      ctx.standing
      |> Ash.reload!(authorize?: false)
      |> DirectoryCuration.set_excluded(true, "complaints", ctx.staff)

    actions = audit_rows(ctx.store) |> Enum.map(& &1.action)
    assert :directory_slot_overridden in actions
    assert :directory_store_excluded in actions

    [latest | _] = audit_rows(ctx.store)
    assert latest.metadata["store_id"] == ctx.store.id
    assert latest.metadata["reason"]
  end

  test "readmitting logs too", ctx do
    {:ok, _} = DirectoryCuration.set_excluded(ctx.standing, true, "complaints", ctx.staff)

    {:ok, _} =
      ctx.standing
      |> Ash.reload!(authorize?: false)
      |> DirectoryCuration.set_excluded(false, "resolved in merchant's favour", ctx.staff)

    assert :directory_store_readmitted in (audit_rows(ctx.store) |> Enum.map(& &1.action))
  end

  test "pins default to 30 days; exclusions to forever", ctx do
    {:ok, _} = DirectoryCuration.override_slot(ctx.standing, :rising, "launch week", ctx.staff)
    standing = Ash.reload!(ctx.standing, authorize?: false)

    assert_in_delta DateTime.diff(standing.override_until, DateTime.utc_now(), :day), 30, 1

    {:ok, _} = DirectoryCuration.set_excluded(standing, true, "complaints", ctx.staff)
    assert is_nil(Ash.reload!(ctx.standing, authorize?: false).override_until)
  end

  test "the worker clears an expired pin and logs it", ctx do
    {:ok, _} = DirectoryCuration.override_slot(ctx.standing, :rising, "launch week", ctx.staff)

    ctx.standing
    |> Ash.reload!(authorize?: false)
    |> Ash.Changeset.for_update(:override, %{
      override_until: DateTime.add(DateTime.utc_now(), -1, :day)
    })
    |> Ash.update!(authorize?: false)

    Oban.Testing.with_testing_mode(:manual, fn -> :ok end)

    assert :ok =
             Emakola.Stores.Workers.DirectoryRankingWorker.perform(%Oban.Job{args: %{}})

    standing = Ash.reload!(ctx.standing, authorize?: false)
    assert is_nil(standing.override_slot)
    assert is_nil(standing.override_until)
    assert :directory_override_expired in (audit_rows(ctx.store) |> Enum.map(& &1.action))
  end
end
