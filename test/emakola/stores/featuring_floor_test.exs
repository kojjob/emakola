defmodule Emakola.Stores.FeaturingFloorTest do
  @moduledoc """
  The project owner's switch under the directory's featured slots.

  A young marketplace cannot clear the floor — payout verification needs a
  live payout rail — so the switch ships off and the owner turns it on from
  /platform/settings once merchants can actually pass.
  """
  use Emakola.DataCase, async: false

  alias Emakola.FeatureFlags

  @key "directory_featuring_floor"

  defp flag!, do: FeatureFlags.get_flag_by_key(@key) |> elem(1)

  defp set_floor!(enabled) do
    {:ok, _flag} = FeatureFlags.update_flag(flag!(), %{enabled: enabled}, authorize?: false)
    :ok
  end

  describe "featuring_floor_enforced?/0" do
    test "the switch ships off — the young-marketplace default" do
      refute Emakola.Stores.featuring_floor_enforced?()
    end

    test "the owner turning it on enforces the floor" do
      set_floor!(true)

      assert Emakola.Stores.featuring_floor_enforced?()
    end

    test "and turning it off again suspends the floor" do
      set_floor!(true)
      set_floor!(false)

      refute Emakola.Stores.featuring_floor_enforced?()
    end

    test "a missing flag row reads as off, never as on" do
      :ok = FeatureFlags.destroy_flag(flag!(), authorize?: false)

      refute Emakola.Stores.featuring_floor_enforced?()
    end
  end
end
