defmodule Emakola.Stores.Workers.DirectoryRankingWorkerTest do
  @moduledoc """
  The nightly run that joins the pure pieces: signals in one query,
  eligibility and score per store, slots across the population, one
  transactional write. The invariants here are the ones the plan calls
  load-bearing — idempotency, override preservation, cache consistency.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  require Ash.Query

  import Emakola.Factory
  import Swoosh.TestAssertions

  alias Emakola.Stores.DirectoryStanding
  alias Emakola.Stores.Store
  alias Emakola.Stores.Workers.DirectoryRankingWorker

  defp equipped_store!(attrs \\ %{}) do
    store =
      create_store!(
        Map.merge(
          %{
            logo_url: "https://cdn.example/logo.png",
            tagline: "Real goods, really delivered",
            contact_phone: "+233201234567",
            region: "greater_accra"
          },
          attrs
        )
      )

    for _ <- 1..3 do
      create_product!(store) |> Ash.Seed.update!(%{status: :active})
    end

    Ash.Seed.seed!(Emakola.Stores.StorePayoutAccount, %{
      store_id: store.id,
      payout_destination: %{"momo_number" => "0241234567"},
      verification_status: :verified
    })

    store
  end

  defp standing_for(store) do
    DirectoryStanding
    |> Ash.Query.filter(store_id == ^store.id)
    |> Ash.read_one!(authorize?: false)
  end

  defp reload(store), do: Ash.get!(Store, store.id, authorize?: false)

  test "a full run assesses the population and writes consistent standings and caches" do
    good = equipped_store!(%{name: "Good Shop"})
    create_order!(good, %{status: :delivered})

    bare = create_store!(%{name: "Bare Shop"})

    assert :ok = perform_job(DirectoryRankingWorker, %{})

    good_standing = standing_for(good)
    assert good_standing.eligible
    assert good_standing.disqualifiers == []
    assert good_standing.score > 0
    assert %DateTime{} = good_standing.computed_at

    bare_standing = standing_for(bare)
    refute bare_standing.eligible
    assert :incomplete in bare_standing.disqualifiers
    assert :no_payout in bare_standing.disqualifiers

    # Cache columns mirror the standing — the public read path's truth.
    assert reload(good).directory_eligible
    assert reload(good).directory_score == good_standing.score
    assert reload(good).directory_slot == good_standing.slot
    refute reload(bare).directory_eligible
    assert is_nil(reload(bare).directory_slot)
  end

  test "two consecutive runs produce identical rows — idempotent" do
    equipped_store!(%{name: "Steady Shop"})

    assert :ok = perform_job(DirectoryRankingWorker, %{})
    first = DirectoryStanding |> Ash.read!(authorize?: false) |> normalize()

    assert :ok = perform_job(DirectoryRankingWorker, %{})
    second = DirectoryStanding |> Ash.read!(authorize?: false) |> normalize()

    assert first == second
  end

  test "a staff override survives the nightly recompute" do
    store = equipped_store!(%{name: "Pinned Shop"})
    assert :ok = perform_job(DirectoryRankingWorker, %{})

    standing_for(store)
    |> Ash.Changeset.for_update(:override, %{
      override_slot: :rising,
      override_reason: "launch week pin",
      override_until: DateTime.add(DateTime.utc_now(), 30, :day)
    })
    |> Ash.update!(authorize?: false)

    assert :ok = perform_job(DirectoryRankingWorker, %{})

    survived = standing_for(store)
    assert survived.override_slot == :rising
    assert survived.override_reason == "launch week pin"
    # And the slot the caches carry honours the pin.
    assert reload(store).directory_slot == :rising
  end

  test "an excluded shop holds no slot however well it scores" do
    store = equipped_store!(%{name: "Excluded Shop"})
    for _ <- 1..5, do: create_order!(store, %{status: :delivered})

    assert :ok = perform_job(DirectoryRankingWorker, %{})

    standing_for(store)
    |> Ash.Changeset.for_update(:override, %{
      override_excluded: true,
      override_reason: "counterfeit complaints under review"
    })
    |> Ash.update!(authorize?: false)

    assert :ok = perform_job(DirectoryRankingWorker, %{})

    assert is_nil(standing_for(store).slot)
    assert is_nil(reload(store).directory_slot)
  end

  test "a platform-suspended history flags conduct" do
    store = equipped_store!(%{name: "Suspended Once"})

    Emakola.Accounts.PlatformAudit.log(
      :store_suspended,
      create_platform_owner!(),
      %{"store_id" => store.id, "store_slug" => store.slug}
    )

    assert :ok = perform_job(DirectoryRankingWorker, %{})

    assert :conduct in standing_for(store).disqualifiers
  end

  defp normalize(standings) do
    standings
    |> Enum.map(&Map.take(&1, [:store_id, :eligible, :disqualifiers, :score, :slot]))
    |> Enum.sort_by(& &1.store_id)
  end

  describe "the drop email" do
    test "losing eligibility emails the owner once, with the reasons", %{} do
      store = equipped_store!(%{name: "Slipping Shop"})
      owner = create_merchant!(%{email: "owner@example.com"})
      create_store_membership!(owner, store, :owner)

      # Registration sends onboarding emails; drain them so the drop-email
      # assertions see only what the worker sends.
      drain_mailbox()

      assert :ok = perform_job(DirectoryRankingWorker, %{})
      assert standing_for(store).eligible

      # The payout account lapses — the hardest bar of the four.
      Emakola.Stores.StorePayoutAccount
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.store_id == store.id))
      |> Enum.each(&Ash.Seed.update!(&1, %{verification_status: :unverified}))

      assert :ok = perform_job(DirectoryRankingWorker, %{})
      refute standing_for(store).eligible

      assert_email_sent(fn email ->
        {_name, to} = hd(email.to)
        to == "owner@example.com" and email.text_body =~ "MoMo payout"
      end)

      # Staying ineligible is not news — no second email.
      assert :ok = perform_job(DirectoryRankingWorker, %{})
      assert_no_email_sent()
    end

    test "a shop that was never eligible gets no email on first assessment" do
      store = create_store!(%{name: "Bare From Birth"})
      owner = create_merchant!(%{email: "bare@example.com"})
      create_store_membership!(owner, store, :owner)

      drain_mailbox()

      assert :ok = perform_job(DirectoryRankingWorker, %{})

      assert_no_email_sent()
      _ = store
    end
  end

  # Swallows whatever onboarding mail the factories triggered, so the
  # drop-email assertions see only what the worker sends.
  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end
end
