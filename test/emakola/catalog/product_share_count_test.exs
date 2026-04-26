defmodule Emakola.Catalog.ProductShareCountTest do
  @moduledoc """
  Pins the contract for the Product.share_count + :increment_share_count
  action introduced in Phase 3:

    * Defaults to 0
    * Atomic increment moves count up by 1
    * Concurrent increments don't interleave (atomic via SQL update)
    * No actor required — public/anonymous storefront tracking
  """
  use Emakola.DataCase, async: false

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Share Shop", slug: "share-shop"})
    product = Factory.create_product!(store, %{title: "Trackable Item"})
    {:ok, store: store, product: product}
  end

  describe "share_count attribute" do
    test "defaults to 0", %{product: product} do
      assert product.share_count == 0
    end
  end

  describe ":increment_share_count action" do
    test "increments by 1 each call", %{product: product} do
      {:ok, p1} =
        product
        |> Ash.Changeset.for_update(:increment_share_count, %{})
        |> Ash.update(authorize?: false)

      assert p1.share_count == 1

      {:ok, p2} =
        p1
        |> Ash.Changeset.for_update(:increment_share_count, %{})
        |> Ash.update(authorize?: false)

      assert p2.share_count == 2

      {:ok, p3} =
        p2
        |> Ash.Changeset.for_update(:increment_share_count, %{})
        |> Ash.update(authorize?: false)

      assert p3.share_count == 3
    end

    test "concurrent increments are atomic — no lost updates", %{product: product} do
      # Fire 10 concurrent increments. Atomic SQL UPDATE expr should make
      # the final count exactly 10 (no race-condition lost updates).
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            product
            |> Ash.Changeset.for_update(:increment_share_count, %{})
            |> Ash.update(authorize?: false)
          end)
        end

      Enum.each(tasks, &Task.await/1)

      reloaded = Ash.reload!(product, authorize?: false)
      assert reloaded.share_count == 10
    end
  end
end
