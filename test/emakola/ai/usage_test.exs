defmodule Emakola.AI.UsageTest do
  use Emakola.DataCase, async: true

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        store_id: Ash.UUID.generate(),
        feature: "product_description",
        provider: "anthropic",
        model: "claude-haiku-4-5",
        input_tokens: 100,
        output_tokens: 50,
        cost_microusd: 350,
        status: :success,
        latency_ms: 12
      },
      overrides
    )
  end

  test "records a usage row" do
    assert {:ok, usage} = Emakola.AI.record_usage(attrs(), authorize?: false)
    assert usage.feature == "product_description"
    assert usage.cost_microusd == 350
    assert usage.status == :success
  end

  test "allows a nil store_id (platform-scoped calls)" do
    assert {:ok, usage} = Emakola.AI.record_usage(attrs(%{store_id: nil}), authorize?: false)
    assert is_nil(usage.store_id)
  end

  test "rejects an unknown status" do
    assert {:error, _} = Emakola.AI.record_usage(attrs(%{status: :bogus}), authorize?: false)
  end

  test "usage_for_store returns only that store's rows, newest first" do
    store_a = Ash.UUID.generate()
    store_b = Ash.UUID.generate()

    {:ok, _} =
      Emakola.AI.record_usage(attrs(%{store_id: store_a, feature: "older"}), authorize?: false)

    {:ok, _} =
      Emakola.AI.record_usage(attrs(%{store_id: store_a, feature: "newer"}), authorize?: false)

    {:ok, _} = Emakola.AI.record_usage(attrs(%{store_id: store_b}), authorize?: false)

    rows = Emakola.AI.usage_for_store!(store_a)
    assert length(rows) == 2
    assert Enum.all?(rows, &(&1.store_id == store_a))
  end
end
