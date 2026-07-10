defmodule Emakola.Suppliers.ContentStudioTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Suppliers.{ContentStudio, ListingImporter, Network, Offers}

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()

    product =
      create_product!(supplier,
        status: :active,
        title: "Grounded Kente",
        description: "Handwoven cotton cloth."
      )

    variant = create_variant!(product, supplier, stock_quantity: 10)

    {:ok, offer} =
      Offers.create_draft(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Accra"],
        return_terms: "Returns within 7 days."
      })

    {:ok, _terms} =
      Offers.add_variant(supplier_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 5_000,
        suggested_retail_price: 6_500,
        max_retail_price: 7_000
      })

    {:ok, offer} = Offers.publish(supplier_actor, offer)

    {:ok, pending} =
      Network.request(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: supplier.id
      })

    {:ok, _active} = Network.approve(reseller_actor, pending)
    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, offer)

    %{actor: reseller_actor, store: reseller, listing: listing}
  end

  test "creates a merchant-reviewable draft from supplier facts only", ctx do
    assert {:ok, draft} = ContentStudio.create_draft(ctx.actor, ctx.store.id, ctx.listing.id)

    assert draft.status == :draft
    assert draft.generator == "deterministic"
    assert draft.source_facts["product_title"] == "Grounded Kente"
    assert draft.source_facts["prices"] == [6_500]
    assert draft.content["whatsapp"] =~ "Grounded Kente"
    assert draft.content["whatsapp"] =~ "GH₵65.00"
    assert draft.content["whatsapp"] =~ "Handwoven cotton cloth."
    refute draft.content["whatsapp"] =~ "guaranteed"

    assert {:ok, approved} = ContentStudio.approve(ctx.actor, ctx.store.id, draft.id)
    assert approved.status == :approved
    assert approved.approved_by_id == ctx.actor.id
    assert approved.approved_at
  end

  test "does not expose or approve another store's draft", ctx do
    assert {:ok, draft} = ContentStudio.create_draft(ctx.actor, ctx.store.id, ctx.listing.id)
    {other_actor, other_store} = create_merchant_with_store!()

    assert {:error, :forbidden} =
             ContentStudio.create_draft(other_actor, other_store.id, ctx.listing.id)

    assert {:error, :forbidden} = ContentStudio.approve(other_actor, other_store.id, draft.id)
  end
end
