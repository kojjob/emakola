defmodule Emakola.Orders.CheckoutDigitalTest do
  @moduledoc """
  A cart of downloads has nothing to deliver, so it must not be charged a
  delivery fee. The gate lives in CheckoutService, not the LiveView, because
  the fee arrives as a caller-supplied option — a crafted socket message could
  otherwise attach GHS 35 of "delivery" to a file. Putting it here also covers
  PayLinkLive, the other checkout!/3 caller, for free.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.CheckoutService

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  # :product is loaded because that is what load_and_validate_variants/2 hands
  # run_checkout/4 in production. An unloaded product is treated as shipping —
  # the conservative default — so a fixture without it would test nothing.
  defp digital_variant!(store) do
    product = create_product!(store, product_type: :digital_download)

    create_variant!(product, store,
      price: 50_000,
      sku: "DIG-#{System.unique_integer([:positive])}"
    )
    |> Ash.load!(:product, authorize?: false)
  end

  defp physical_variant!(store) do
    product = create_product!(store)

    create_variant!(product, store,
      price: 20_000,
      sku: "PHY-#{System.unique_integer([:positive])}",
      stock_quantity: 10
    )
    |> Ash.load!(:product, authorize?: false)
  end

  describe "requires_shipping?/1" do
    test "an all-digital cart does not require shipping" do
      store = digital_store!()
      variant = digital_variant!(store)

      refute CheckoutService.requires_shipping?(%{variant.id => variant})
    end

    test "a physical cart requires shipping" do
      store = create_store!()
      variant = physical_variant!(store)

      assert CheckoutService.requires_shipping?(%{variant.id => variant})
    end

    test "a mixed cart requires shipping" do
      store = digital_store!()
      digital = digital_variant!(store)
      physical = physical_variant!(store)

      assert CheckoutService.requires_shipping?(%{digital.id => digital, physical.id => physical})
    end

    # An empty or fully-stale cart falls back to today's physical behaviour, so
    # a disconnected mount still renders the address form.
    test "an empty cart requires shipping" do
      assert CheckoutService.requires_shipping?(%{})
    end
  end

  describe "checkout!/3 with an all-digital cart" do
    test "forces the delivery fee to zero even when the caller supplies one" do
      store = digital_store!()
      variant = digital_variant!(store)

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          delivery_fee: 3500,
          region: "greater_accra"
        )

      assert order.delivery_fee == 0
      assert order.total == 50_000
    end

    test "charges no dispatch fees" do
      store = digital_store!()
      variant = digital_variant!(store)

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}],
          delivery_fee: 3500
        )

      assert order.dispatch_fee_total == 0
    end
  end

  describe "checkout!/3 with a physical cart" do
    # Regression guard: the change must not touch the shipping path.
    test "still charges the supplied delivery fee" do
      store = create_store!()
      variant = physical_variant!(store)

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}],
          delivery_fee: 3500,
          region: "greater_accra"
        )

      assert order.delivery_fee == 3500
      assert order.total == 20_000 + 3500
    end

    test "a mixed cart still charges delivery" do
      store = digital_store!()
      digital = digital_variant!(store)
      physical = physical_variant!(store)

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [
            %{variant_id: digital.id, quantity: 1},
            %{variant_id: physical.id, quantity: 1}
          ],
          delivery_fee: 3500,
          region: "greater_accra"
        )

      assert order.delivery_fee == 3500
    end
  end
end
