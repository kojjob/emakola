defmodule Emakola.Catalog.ProductShippingTest do
  @moduledoc """
  `product_type` is the single source of truth for whether a line ships.

  There is deliberately no `requires_shipping` boolean: a second field would
  be duplicate state that can drift, and nothing wants a physical product that
  skips shipping or a download that demands an address.
  """
  use ExUnit.Case, async: true

  alias Emakola.Catalog.Product

  describe "requires_shipping?/1" do
    test "a physical product ships" do
      assert Product.requires_shipping?(:physical)
    end

    test "a download does not" do
      refute Product.requires_shipping?(:digital_download)
    end

    test "accepts a product struct, not just the bare atom" do
      assert Product.requires_shipping?(%Product{product_type: :physical})
      refute Product.requires_shipping?(%Product{product_type: :digital_download})
    end

    # Blacklist polarity, deliberately. A type added later without touching
    # this function over-collects an address rather than silently shipping a
    # physical good for free.
    test "an unrecognised type defaults to shipping" do
      assert Product.requires_shipping?(:print_on_demand)
      assert Product.requires_shipping?(:auction)
      assert Product.requires_shipping?(:some_future_type)
    end
  end

  describe "sellable_types/0" do
    test "offers only the types a merchant can actually sell today" do
      assert Product.sellable_types() == [:physical, :digital_download]
    end

    test "every sellable type is a valid product_type" do
      one_of =
        Product
        |> Ash.Resource.Info.attribute(:product_type)
        |> Map.fetch!(:constraints)
        |> Keyword.fetch!(:one_of)

      for type <- Product.sellable_types() do
        assert type in one_of, "#{type} is offered in the UI but is not a valid product_type"
      end
    end

    test "every sellable type has a fulfillment pipeline" do
      supported = Emakola.Fulfillment.Dispatcher.supported_types()

      for type <- Product.sellable_types() do
        assert type in supported, "#{type} is offered in the UI but nothing can fulfill it"
      end
    end

    # The narrower-than-one_of relationship is the point. These five types
    # exist in the resource and route to stub pipelines, but no merchant can
    # deliver one, so offering them in a form would sell a promise the
    # platform cannot keep.
    test "excludes types that have no delivery mechanism yet" do
      for type <- [:license_key, :streaming, :course, :auction, :print_on_demand] do
        refute type in Product.sellable_types(),
               "#{type} has no working delivery path and must not be offered"
      end
    end
  end
end
