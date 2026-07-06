defmodule Emakola.Platform.OnboardingTest do
  @moduledoc """
  Onboarding-health overview: per-store milestone booleans + completed count,
  the funnel totals, and least-complete-first ordering.
  """
  use Emakola.DataCase, async: false

  alias Emakola.Factory
  alias Emakola.Platform.Onboarding
  alias Emakola.Stores

  defp onboard_fully!(store) do
    Factory.create_product!(store)
    Factory.create_order!(store)

    {:ok, _} =
      Stores.create_payout_account(
        %{store_id: store.id, payout_destination: %{"method" => "mobile_money"}},
        authorize?: false
      )

    {:ok, v} =
      Stores.submit_store_verification(
        %{
          store_id: store.id,
          business_name: "Ama Trades",
          id_type: :ghana_card,
          id_number: "GHA-1",
          id_document_key: "k"
        },
        authorize?: false
      )

    {:ok, _} = Stores.approve_store_verification(v, authorize?: false)
    store
  end

  test "a fully-onboarded store has all milestones true and completed == 5" do
    full = Factory.create_store!() |> onboard_fully!()

    overview = Onboarding.overview()
    row = Enum.find(overview.stores, &(&1.id == full.id))

    assert row.milestones == %{
             products: true,
             live: true,
             payout: true,
             kyc: true,
             first_order: true
           }

    assert row.completed == 5
  end

  test "an archived store with nothing set up has completed == 0 (not live)" do
    {:ok, bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()
    row = Enum.find(overview.stores, &(&1.id == bare.id))

    assert row.milestones.live == false
    assert row.completed == 0
  end

  test "funnel counts and total reflect the stores" do
    Factory.create_store!() |> onboard_fully!()
    {:ok, _bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()

    assert overview.total_stores == 2
    assert overview.funnel.products == 1
    assert overview.funnel.first_order == 1
    # one live (the full one; the bare one is archived)
    assert overview.funnel.live == 1
  end

  test "stores are sorted least-complete first" do
    full = Factory.create_store!() |> onboard_fully!()
    {:ok, bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()
    ids = Enum.map(overview.stores, & &1.id)

    assert Enum.find_index(ids, &(&1 == bare.id)) <
             Enum.find_index(ids, &(&1 == full.id))
  end
end
