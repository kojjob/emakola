defmodule Emakola.Catalog.DigitalInventoryTest do
  @moduledoc """
  A file is infinitely copyable, so a digital product must never be inventory
  tracked. With the resource defaults (`track_inventory: true`,
  `stock_quantity: 0`) it is otherwise born permanently out of stock: the PDP
  hides Add-to-Cart, `CheckoutService.validate_stock/2` refuses it, and
  `DecrementStock` would burn a unit at a physical warehouse location for a
  download.

  Forcing the flag rather than bypassing the stock check is deliberate — five
  separate readers already branch correctly on `track_inventory == false`, so
  one flag fixes all of them, whereas a `validate_stock` bypass fixes only the
  checkout and leaves the product un-addable to cart.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query

  alias Emakola.Catalog.Variant

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp reload_variants(product) do
    Variant
    |> Ash.Query.filter(product_id == ^product.id)
    |> Ash.read!(authorize?: false)
  end

  describe "variants of a digital product" do
    test "are never inventory tracked, even when the caller asks for tracking" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)

      variant = create_variant!(product, store, track_inventory: true, stock_quantity: 0)

      refute variant.track_inventory
    end

    test "are in stock at zero quantity" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, stock_quantity: 0)

      assert Variant.in_stock?(variant, 1)
    end
  end

  describe "variants of a physical product" do
    # Regression guard: the change must be narrow. Physical inventory tracking
    # is the default and must survive untouched.
    test "keep their tracking setting" do
      store = create_store!()
      product = create_product!(store)
      variant = create_variant!(product, store, track_inventory: true, stock_quantity: 5)

      assert variant.track_inventory
    end
  end

  describe "switching an existing product's type" do
    test "physical -> digital untracks its existing variants" do
      store = digital_store!()
      product = create_product!(store)
      variant = create_variant!(product, store, track_inventory: true, stock_quantity: 5)
      assert variant.track_inventory

      product
      |> Ash.Changeset.for_update(:update, %{product_type: :digital_download})
      |> Ash.update!(authorize?: false)

      assert [reloaded] = reload_variants(product)
      refute reloaded.track_inventory
    end

    # Deliberately one-directional. Re-tracking would restore
    # `stock_quantity: 0` on a live product and yank it off the storefront,
    # and a deliberately untracked own-stock variant is a state the sibling
    # change (UntrackDropshippedInventory) also preserves.
    test "digital -> physical does NOT re-track them" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store)
      refute variant.track_inventory

      product
      |> Ash.Changeset.for_update(:update, %{product_type: :physical})
      |> Ash.update!(authorize?: false)

      assert [reloaded] = reload_variants(product)
      refute reloaded.track_inventory
    end
  end
end
