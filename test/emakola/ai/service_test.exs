defmodule Emakola.AITest do
  # async: false — drives the globally-configured :ai_provider (ProviderMock).
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.AI.Response

  setup :verify_on_exit!

  defp store, do: %{id: Ash.UUID.generate(), name: "Ama's Shop", currency: "GHS"}

  test "emoji in the provider's reply never reach the caller" do
    s = store()

    expect(Emakola.AI.ProviderMock, :complete, fn _request ->
      {:ok,
       %Response{
         text: "Soft shea butter 🧴✨ for dry skin.",
         parsed: %{"title" => "Shea Butter 🧴", "description" => "Whipped ✨ and unscented"},
         model: "claude-haiku-4-5",
         usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
       }}
    end)

    assert {:ok, %Response{text: text, parsed: parsed}} =
             Emakola.AI.generate(:seo_meta, %{resource: %{title: "Shea"}, store: s}, store: s)

    assert text == "Soft shea butter for dry skin."
    assert parsed == %{"title" => "Shea Butter", "description" => "Whipped and unscented"}
  end

  test "generate/3 returns the provider response and records a success usage row" do
    s = store()

    expect(Emakola.AI.ProviderMock, :complete, fn request ->
      assert request.feature == :product_description
      assert request.store_id == s.id
      assert request.model == "claude-haiku-4-5"

      {:ok,
       %Response{
         text: "A handwoven kente cloth.",
         model: "claude-haiku-4-5",
         usage: %{input_tokens: 100, output_tokens: 50, cache_read: 0, cache_creation: 0}
       }}
    end)

    assert {:ok, %Response{text: "A handwoven kente cloth."}} =
             Emakola.AI.generate(
               :product_description,
               %{product: %{title: "Kente"}, store: s},
               store: s
             )

    assert [usage] = Emakola.AI.usage_for_store!(s.id)
    assert usage.status == :success
    assert usage.feature == "product_description"
    assert usage.input_tokens == 100
    assert usage.output_tokens == 50
    # haiku: 100 * 1 + 50 * 5 = 350 micro-USD
    assert usage.cost_microusd == 350
  end

  test "records a :not_configured row and returns the error when ships dark" do
    s = store()
    expect(Emakola.AI.ProviderMock, :complete, fn _request -> {:error, :not_configured} end)

    assert {:error, :not_configured} =
             Emakola.AI.generate(:product_description, %{product: %{title: "x"}, store: s},
               store: s
             )

    assert [usage] = Emakola.AI.usage_for_store!(s.id)
    assert usage.status == :not_configured
    assert usage.cost_microusd == 0
  end

  test "records an :error row and returns the error on provider failure" do
    s = store()
    expect(Emakola.AI.ProviderMock, :complete, fn _request -> {:error, :boom} end)

    assert {:error, :boom} =
             Emakola.AI.generate(:product_description, %{product: %{title: "x"}, store: s},
               store: s
             )

    assert [usage] = Emakola.AI.usage_for_store!(s.id)
    assert usage.status == :error
    assert usage.error =~ "boom"
  end

  test "platform-scoped calls (no store) record a nil store_id" do
    expect(Emakola.AI.ProviderMock, :complete, fn _request ->
      {:ok,
       %Response{
         text: "ok",
         model: "claude-opus-4-8",
         usage: %{input_tokens: 1, output_tokens: 1}
       }}
    end)

    assert {:ok, _} =
             Emakola.AI.generate(:product_description, %{
               product: %{title: "x"},
               store: %{name: "n"}
             })

    # No store_id → not retrievable via usage_for_store; assert the row exists globally.
    rows = Ash.read!(Emakola.AI.Usage)
    assert Enum.any?(rows, &is_nil(&1.store_id))
  end
end
