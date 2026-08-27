defmodule Emakola.Stores.DirectoryEligibilityTest do
  @moduledoc """
  The floor under every featured slot. These tests pin the four
  disqualifiers the product owner chose — and the grace period, without
  which a brand-new shop is "abandoned" on day one and the growth slot
  can never fill.
  """
  use ExUnit.Case, async: true

  alias Emakola.Stores.DirectoryEligibility

  @now ~U[2026-08-26 12:00:00.000000Z]

  defp equipped(overrides) do
    Map.merge(
      %{
        logo_url: "https://cdn/logo.png",
        cover_image_url: nil,
        tagline: "Fresh from Mallam Atta",
        description: nil,
        contact_phone: "+233201234567",
        whatsapp_number: nil,
        contact_email: nil,
        region: "greater_accra",
        product_count: 5,
        payout_verified?: true,
        inserted_at: DateTime.add(@now, -120, :day),
        last_product_published_at: DateTime.add(@now, -10, :day),
        last_order_at: DateTime.add(@now, -5, :day),
        taken_down_products_90d: 0,
        conduct_flagged?: false
      },
      overrides
    )
  end

  test "a fully equipped shop is eligible with nothing against it" do
    assert {true, []} = DirectoryEligibility.evaluate(equipped(%{}), @now)
  end

  describe "the grace period" do
    test "a 3-day-old shop with no orders and no publishes is NOT abandoned" do
      young =
        equipped(%{
          inserted_at: DateTime.add(@now, -3, :day),
          last_product_published_at: nil,
          last_order_at: nil
        })

      assert {true, []} = DirectoryEligibility.evaluate(young, @now)
    end

    test "a 200-day-old shop with no orders and nothing republished IS abandoned" do
      stale =
        equipped(%{
          inserted_at: DateTime.add(@now, -200, :day),
          last_product_published_at: nil,
          last_order_at: nil
        })

      assert {false, [:abandoned]} = DirectoryEligibility.evaluate(stale, @now)
    end

    test "one recent order keeps an old quiet catalog alive" do
      trading =
        equipped(%{
          inserted_at: DateTime.add(@now, -400, :day),
          last_product_published_at: DateTime.add(@now, -200, :day),
          last_order_at: DateTime.add(@now, -20, :day)
        })

      assert {true, []} = DirectoryEligibility.evaluate(trading, @now)
    end
  end

  describe "each disqualifier bars alone and names itself" do
    test "no card image" do
      shop = equipped(%{logo_url: nil, cover_image_url: nil})
      assert {false, [:incomplete]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "no words at all" do
      shop = equipped(%{tagline: nil, description: nil})
      assert {false, [:incomplete]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "blank strings do not count as words" do
      shop = equipped(%{tagline: "   ", description: ""})
      assert {false, [:incomplete]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "no way to be reached" do
      shop = equipped(%{contact_phone: nil, whatsapp_number: nil, contact_email: nil})
      assert {false, [:incomplete]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "too few products" do
      shop = equipped(%{product_count: 2})
      assert {false, [:incomplete]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "cannot take money" do
      shop = equipped(%{payout_verified?: false})
      assert {false, [:no_payout]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "a recent takedown is conduct" do
      shop = equipped(%{taken_down_products_90d: 1})
      assert {false, [:conduct]} = DirectoryEligibility.evaluate(shop, @now)
    end

    test "a platform conduct flag is conduct" do
      shop = equipped(%{conduct_flagged?: true})
      assert {false, [:conduct]} = DirectoryEligibility.evaluate(shop, @now)
    end
  end

  test "multiple failures all report, not just the first" do
    wreck =
      equipped(%{
        logo_url: nil,
        cover_image_url: nil,
        payout_verified?: false,
        conduct_flagged?: true
      })

    assert {false, disqualifiers} = DirectoryEligibility.evaluate(wreck, @now)
    assert Enum.sort(disqualifiers) == [:conduct, :incomplete, :no_payout]
  end
end
