defmodule Emakola.Suppliers.FranchisesTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  alias Emakola.Suppliers.{Franchises, Network, Offers}

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()
    product = create_product!(supplier, status: :active, title: "Franchise Soap")
    variant = create_variant!(product, supplier, stock_quantity: 20)

    {:ok, offer} =
      Offers.create_draft(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        source_product_id: product.id,
        earning_model: :fixed_commission
      })

    {:ok, _terms} =
      Offers.add_variant(supplier_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 5_000,
        suggested_retail_price: 6_000,
        fixed_commission_amount: 1_000
      })

    {:ok, offer} = Offers.publish(supplier_actor, offer)

    {:ok, pending} =
      Network.request(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: supplier.id
      })

    {:ok, _active} = Network.approve(reseller_actor, pending)

    %{
      supplier_actor: supplier_actor,
      supplier: supplier,
      reseller_actor: reseller_actor,
      reseller: reseller,
      offer: offer
    }
  end

  test "publishes a complete product-sales package and requires reseller terms acceptance", ctx do
    assert {:ok, package} = Franchises.create(ctx.supplier_actor, ctx.supplier.id, attrs(ctx))
    assert package.status == :draft
    assert {:ok, published} = Franchises.publish(ctx.supplier_actor, ctx.supplier.id, package.id)
    assert published.status == :published

    assert {:ok, [available]} = Franchises.discover(ctx.reseller_actor, ctx.reseller.id)
    assert available.id == package.id

    assert {:error, :terms_must_be_accepted} =
             Franchises.apply(ctx.reseller_actor, ctx.reseller.id, package.id, false)

    assert {:ok, enrollment} =
             Franchises.apply(ctx.reseller_actor, ctx.reseller.id, package.id, true)

    assert enrollment.terms_accepted_at

    assert {:ok, approved} =
             Franchises.approve(ctx.supplier_actor, ctx.supplier.id, enrollment.id)

    assert approved.status == :approved
  end

  test "rejects incomplete packages and contains no recruitment economics", ctx do
    incomplete = attrs(ctx) |> Map.put(:training, %{})
    assert {:ok, package} = Franchises.create(ctx.supplier_actor, ctx.supplier.id, incomplete)

    assert {:error, :package_incomplete} =
             Franchises.publish(ctx.supplier_actor, ctx.supplier.id, package.id)

    fields =
      Emakola.Suppliers.FranchisePackage |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

    refute :recruiter_id in fields
    refute :parent_id in fields
    refute :downline_commission_bps in fields
  end

  defp attrs(ctx) do
    %{
      name: "Clean Home Partner",
      offer_ids: [ctx.offer.id],
      training: %{"lessons" => ["Product safety", "Customer care"]},
      brand_rules: %{"claims" => "Use supplier-approved facts only"},
      channel_permissions: [:storefront, :whatsapp],
      territory: "Greater Accra",
      commission_bps: 1_000
    }
  end
end
