defmodule Emakola.Stores.FeaturingChecklistTest do
  @moduledoc """
  The merchant-facing half of the eligibility floor: the same four bars,
  phrased as things a merchant can do this afternoon. Pure — counts and
  flags in, checklist out — in the SetupChecklist style.
  """
  use ExUnit.Case, async: true

  alias Emakola.Stores.FeaturingChecklist

  defp store(overrides) do
    Map.merge(
      %{
        logo_url: "https://cdn/logo.png",
        cover_image_url: nil,
        tagline: "Fresh from the market",
        description: nil,
        contact_phone: "+233201234567",
        whatsapp_number: nil,
        contact_email: nil,
        region: "greater_accra"
      },
      overrides
    )
  end

  @opts [product_count: 5, payout_verified?: true, active_recently?: true]

  test "a fully equipped shop checks every item and is eligible" do
    items = FeaturingChecklist.items(store(%{}), @opts)

    assert Enum.all?(items, & &1.done?)
    assert FeaturingChecklist.eligible?(items)
  end

  test "each missing piece unchecks exactly its own item" do
    for {overrides, opts, id} <- [
          {%{logo_url: nil, cover_image_url: nil}, @opts, :photo},
          {%{tagline: nil, description: nil}, @opts, :words},
          {%{contact_phone: nil, whatsapp_number: nil, contact_email: nil}, @opts, :contact},
          {%{region: nil}, @opts, :region},
          {%{}, Keyword.put(@opts, :product_count, 1), :products},
          {%{}, Keyword.put(@opts, :payout_verified?, false), :payout},
          {%{}, Keyword.put(@opts, :active_recently?, false), :activity}
        ] do
      items = FeaturingChecklist.items(store(overrides), opts)
      undone = items |> Enum.reject(& &1.done?) |> Enum.map(& &1.id)

      assert undone == [id], "expected only #{id} unchecked, got #{inspect(undone)}"
      refute FeaturingChecklist.eligible?(items)
    end
  end

  test "every item carries a short, plain label a merchant can act on" do
    for item <- FeaturingChecklist.items(store(%{}), @opts) do
      assert is_binary(item.label)
      # The low-literacy ceiling: eight words, no more.
      assert length(String.split(item.label)) <= 8
    end
  end
end
