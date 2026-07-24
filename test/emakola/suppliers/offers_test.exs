defmodule Emakola.Suppliers.OffersTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Suppliers.{GhanaRegions, Network, Offers}

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Offer wholesaler"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Offer reseller"})
    product = create_product!(wholesaler, status: :active, title: "Shared shea butter")

    variant =
      create_variant!(product, wholesaler,
        price: 5_000,
        sku: "SHEA-500",
        stock_quantity: 10
      )

    product_2 = create_product!(wholesaler, status: :active, title: "Shared cocoa")

    variant_2 =
      create_variant!(product_2, wholesaler,
        price: 8_000,
        sku: "COCOA-500",
        stock_quantity: 15
      )

    {:ok,
     wholesaler_actor: wholesaler_actor,
     wholesaler: wholesaler,
     reseller_actor: reseller_actor,
     reseller: reseller,
     product: product,
     variant: variant,
     product_2: product_2,
     variant_2: variant_2}
  end

  test "a duplicate add_variant for an already-terms'd variant is a clean identity error",
       context do
    offer = draft_offer!(context, :markup)

    {:ok, _terms} =
      Offers.add_variant(context.wholesaler_actor, offer, %{
        source_variant_id: context.variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_000
      })

    assert {:error, %Ash.Error.Invalid{} = error} =
             Offers.add_variant(context.wholesaler_actor, offer, %{
               source_variant_id: context.variant.id,
               supplier_price: 3_100,
               suggested_retail_price: 4_100
             })

    assert Exception.message(error) =~ "already been taken"
  end

  test "creates terms that reference, rather than copy, existing catalog records", context do
    offer = draft_offer!(context, :markup)

    assert offer.source_product_id == context.product.id
    assert offer.wholesaler_store_id == context.wholesaler.id
    assert offer.status == :draft

    assert {:ok, terms} =
             Offers.add_variant(context.wholesaler_actor, offer, %{
               source_variant_id: context.variant.id,
               supplier_price: 3_000,
               suggested_retail_price: 4_000,
               max_retail_price: 5_000
             })

    assert terms.source_variant_id == context.variant.id
    assert terms.supplier_price == 3_000
  end

  test "rejects catalog records owned by another store", context do
    foreign_product = create_product!(context.reseller, status: :active)

    assert {:error, :product_not_owned} =
             Offers.create_draft(context.wholesaler_actor, %{
               wholesaler_store_id: context.wholesaler.id,
               source_product_id: foreign_product.id,
               earning_model: :markup
             })

    offer = draft_offer!(context, :markup)
    foreign_variant = create_variant!(foreign_product, context.reseller)

    assert {:error, :variant_not_owned} =
             Offers.add_variant(context.wholesaler_actor, offer, %{
               source_variant_id: foreign_variant.id,
               supplier_price: 3_000,
               suggested_retail_price: 4_000
             })
  end

  test "fixed commission terms must exactly reconcile customer price and supplier net", context do
    offer = draft_offer!(context, :fixed_commission)

    assert {:error, :invalid_fixed_commission_terms} =
             Offers.add_variant(context.wholesaler_actor, offer, %{
               source_variant_id: context.variant.id,
               supplier_price: 3_000,
               suggested_retail_price: 4_000,
               fixed_commission_amount: 500
             })

    assert {:ok, terms} =
             Offers.add_variant(context.wholesaler_actor, offer, %{
               source_variant_id: context.variant.id,
               supplier_price: 3_000,
               suggested_retail_price: 4_000,
               fixed_commission_amount: 1_000
             })

    assert terms.fixed_commission_amount == 1_000
  end

  test "cannot publish without sellable source content and available terms", context do
    draft_product = create_product!(context.wholesaler, title: "Not ready")
    draft_variant = create_variant!(draft_product, context.wholesaler)

    {:ok, offer} =
      Offers.create_draft(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        source_product_id: draft_product.id,
        earning_model: :markup
      })

    {:ok, _} =
      Offers.add_variant(context.wholesaler_actor, offer, %{
        source_variant_id: draft_variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_000
      })

    assert {:error, :source_product_not_sellable} =
             Offers.publish(context.wholesaler_actor, offer)

    empty_offer = draft_offer!(context, :markup)

    assert {:error, :offer_requires_variants} =
             Offers.publish(context.wholesaler_actor, empty_offer)
  end

  test "only active supply partners can discover a published offer", context do
    offer = publish_offer!(context)

    assert {:ok, []} = Offers.list_available(context.reseller_actor, context.reseller.id)

    {:ok, connection} =
      Network.request(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        reseller_store_id: context.reseller.id,
        requested_by_store_id: context.wholesaler.id
      })

    {:ok, _active} = Network.approve(context.reseller_actor, connection)

    assert {:ok, [available]} = Offers.list_available(context.reseller_actor, context.reseller.id)
    assert available.id == offer.id
    assert available.source_product.id == context.product.id
    assert length(available.offer_variants) == 1
  end

  test "a paused offer disappears from partner discovery", context do
    offer = publish_offer!(context)

    {:ok, connection} =
      Network.request(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        reseller_store_id: context.reseller.id,
        requested_by_store_id: context.wholesaler.id
      })

    {:ok, _} = Network.approve(context.reseller_actor, connection)
    assert {:ok, [_]} = Offers.list_available(context.reseller_actor, context.reseller.id)

    assert {:ok, paused} = Offers.pause(context.wholesaler_actor, offer)
    assert paused.status == :paused
    assert {:ok, []} = Offers.list_available(context.reseller_actor, context.reseller.id)
  end

  test "discovery reads live source availability instead of a copied flag", context do
    _offer = publish_offer!(context)

    {:ok, connection} =
      Network.request(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        reseller_store_id: context.reseller.id,
        requested_by_store_id: context.wholesaler.id
      })

    {:ok, _} = Network.approve(context.reseller_actor, connection)
    assert {:ok, [_]} = Offers.list_available(context.reseller_actor, context.reseller.id)

    context.variant
    |> Ash.Changeset.for_update(:update, %{available: false})
    |> Ash.update!(authorize?: false)

    assert {:ok, []} = Offers.list_available(context.reseller_actor, context.reseller.id)
  end

  test "non-owners cannot manage or browse for another store", context do
    assert {:error, :forbidden} =
             Offers.create_draft(context.reseller_actor, %{
               wholesaler_store_id: context.wholesaler.id,
               source_product_id: context.product.id,
               earning_model: :markup
             })

    assert {:error, :forbidden} =
             Offers.list_available(context.wholesaler_actor, context.reseller.id)
  end

  describe "update_terms/3 — what the supplier will honour back to the reseller" do
    test "the owning supplier states a returns window and a warranty", context do
      offer = draft_offer!(context, :markup)

      assert {:ok, updated} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 returns_window_days: 7,
                 warranty_months: 6,
                 warranty_terms: "Manufacturing defects only."
               })

      assert updated.returns_window_days == 7
      assert updated.warranty_months == 6
      assert updated.warranty_terms == "Manufacturing defects only."
    end

    test "terms can be corrected on a LIVE offer without unpublishing it", context do
      published = publish_offer!(context)

      assert {:ok, updated} =
               Offers.update_terms(context.wholesaler_actor, published, %{returns_window_days: 14})

      # Unpublishing to fix a warranty would pause every reseller's listing, so
      # suppliers would leave stale terms live instead. The offer stays up.
      assert updated.status == :published
      assert updated.returns_window_days == 14
    end

    test "a reseller cannot rewrite their supplier's terms", context do
      offer = draft_offer!(context, :markup)

      assert {:error, :forbidden} =
               Offers.update_terms(context.reseller_actor, offer, %{returns_window_days: 365})
    end
  end

  describe "dispatch_fees" do
    test "accepts per-area non-negative integer fees within delivery_areas", context do
      offer = draft_offer!(context, :markup)

      assert {:ok, updated} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => 1_500}
               })

      assert updated.dispatch_fees == %{"Greater Accra" => 1_500}
    end

    test "defaults to an empty map", context do
      offer = draft_offer!(context, :markup)
      assert offer.dispatch_fees == %{}
    end

    test "rejects a fee for an area not in delivery_areas", context do
      offer = draft_offer!(context, :markup)

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Volta" => 1_000}
               })
    end

    test "rejects negative and non-integer fees", context do
      offer = draft_offer!(context, :markup)

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => -5}
               })

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => "15"}
               })
    end
  end

  describe "update_variant/4 and remove_variant/3" do
    test "reprices and removes variants while the offer is a draft", context do
      offer = draft_offer!(context, :markup)

      {:ok, terms} =
        Offers.add_variant(context.wholesaler_actor, offer, %{
          source_variant_id: context.variant.id,
          supplier_price: 3_000,
          suggested_retail_price: 4_000
        })

      assert {:ok, updated} =
               Offers.update_variant(context.wholesaler_actor, offer, terms, %{
                 supplier_price: 3_200,
                 suggested_retail_price: 4_800
               })

      assert updated.supplier_price == 3_200

      assert :ok = Offers.remove_variant(context.wholesaler_actor, offer, updated)

      assert {:error, :offer_requires_variants} =
               Offers.publish(context.wholesaler_actor, offer)
    end

    test "allows editing while paused, and republish re-validates economics", context do
      published = publish_offer!(context)
      {:ok, paused} = Offers.pause(context.wholesaler_actor, published)

      [terms] =
        paused |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)

      # Equal prices pass resource validation but must fail service-level markup rule
      assert {:ok, updated} =
               Offers.update_variant(context.wholesaler_actor, paused, terms, %{
                 supplier_price: 3_500,
                 suggested_retail_price: 3_500
               })

      assert updated.supplier_price == 3_500

      assert {:error, :invalid_offer_economics} =
               Offers.publish(context.wholesaler_actor, paused)
    end

    test "rejects edits with suggested_retail_price <= supplier_price", context do
      offer = draft_offer!(context, :markup)

      # Resource-level validation: suggested must be strictly > supplier
      assert {:error, _} =
               Offers.add_variant(context.wholesaler_actor, offer, %{
                 source_variant_id: context.variant.id,
                 supplier_price: 3_500,
                 suggested_retail_price: 3_400
               })
    end

    test "rejects edits on published offers and for foreign actors", context do
      published = publish_offer!(context)

      [terms] =
        published |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)

      assert {:error, :offer_not_editable} =
               Offers.update_variant(context.wholesaler_actor, published, terms, %{
                 supplier_price: 1
               })

      assert {:error, :offer_not_editable} =
               Offers.remove_variant(context.wholesaler_actor, published, terms)

      {:ok, paused} = Offers.pause(context.wholesaler_actor, published)

      assert {:error, :forbidden} =
               Offers.update_variant(context.reseller_actor, paused, terms, %{supplier_price: 1})
    end

    test "rejects a variant that belongs to a DIFFERENT offer, even one the actor also owns",
         context do
      own_offer = draft_offer!(context, :markup)

      foreign_product = create_product!(context.reseller, status: :active)
      foreign_variant = create_variant!(foreign_product, context.reseller, stock_quantity: 5)

      {:ok, foreign_offer} =
        Offers.create_draft(context.reseller_actor, %{
          wholesaler_store_id: context.reseller.id,
          source_product_id: foreign_product.id,
          earning_model: :markup
        })

      {:ok, foreign_terms} =
        Offers.add_variant(context.reseller_actor, foreign_offer, %{
          source_variant_id: foreign_variant.id,
          supplier_price: 3_000,
          suggested_retail_price: 4_000
        })

      assert {:error, :variant_not_owned} =
               Offers.update_variant(context.wholesaler_actor, own_offer, foreign_terms, %{
                 supplier_price: 1
               })

      assert {:error, :variant_not_owned} =
               Offers.remove_variant(context.wholesaler_actor, own_offer, foreign_terms)

      reloaded =
        Ash.get!(Emakola.Suppliers.SupplierOfferVariant, foreign_terms.id, authorize?: false)

      assert reloaded.supplier_price == 3_000
    end
  end

  describe "unarchive/2" do
    test "returns an archived offer to draft", context do
      offer = draft_offer!(context, :markup)
      {:ok, archived} = Offers.archive(context.wholesaler_actor, offer)
      assert archived.status == :archived

      assert {:ok, unarchived} = Offers.unarchive(context.wholesaler_actor, archived)
      assert unarchived.status == :draft
    end

    test "rejects unarchiving a non-archived offer", context do
      offer = draft_offer!(context, :markup)

      assert {:error, %Ash.Error.Invalid{}} = Offers.unarchive(context.wholesaler_actor, offer)
    end

    test "rejects a foreign actor", context do
      offer = draft_offer!(context, :markup)
      {:ok, archived} = Offers.archive(context.wholesaler_actor, offer)

      assert {:error, :forbidden} = Offers.unarchive(context.reseller_actor, archived)
    end
  end

  defp draft_offer!(context, earning_model, opts \\ []) do
    product = Keyword.get(opts, :product, context.product)

    {:ok, offer} =
      Offers.create_draft(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        source_product_id: product.id,
        earning_model: earning_model,
        delivery_areas: ["Greater Accra"],
        return_terms: "Returns accepted within seven days"
      })

    offer
  end

  defp publish_offer!(context, opts \\ []) do
    product = Keyword.get(opts, :product, context.product)
    variant = Keyword.get(opts, :variant, context.variant)

    {:ok, offer} =
      Offers.create_draft(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Greater Accra"],
        return_terms: "Returns accepted within seven days"
      })

    {:ok, _terms} =
      Offers.add_variant(context.wholesaler_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_000,
        max_retail_price: 5_000
      })

    {:ok, published} = Offers.publish(context.wholesaler_actor, offer)
    published
  end

  describe "GhanaRegions" do
    test "exposes the 16 canonical regions" do
      regions = Emakola.Suppliers.GhanaRegions.all()
      assert length(regions) == 16
      assert "Greater Accra" in regions
      assert "Bono East" in regions
    end

    test "from_param canonicalizes snake_case params" do
      assert GhanaRegions.from_param("greater_accra") == "Greater Accra"
      assert GhanaRegions.from_param("bono_east") == "Bono East"
      assert GhanaRegions.from_param("other") == nil
      assert GhanaRegions.from_param("atlantis") == nil
      assert GhanaRegions.from_param(nil) == nil
    end

    test "select_options covers all 16 regions plus Other" do
      options = GhanaRegions.select_options()
      assert length(options) == 17
      assert {"Greater Accra", "greater_accra"} in options
      assert {"Western North", "western_north"} in options
      assert List.last(options) == {"Other", "other"}
    end
  end

  describe "list_discoverable/2" do
    test "includes published offers from UNconnected wholesalers, flagged connected?: false",
         context do
      published = publish_offer!(context)

      assert {:ok, [entry]} =
               Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      assert entry.offer.id == published.id
      assert entry.connected? == false
    end

    test "flags offers from connected wholesalers with connected?: true", context do
      publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      {:ok, _} = Network.approve(context.wholesaler_actor, conn)

      assert {:ok, [entry]} =
               Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      assert entry.connected? == true
    end

    test "excludes the store's own offers and drafts", context do
      _draft_only = draft_offer!(context, :markup)

      assert {:ok, []} = Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      published = publish_offer!(context, product: context.product_2, variant: context.variant_2)

      assert {:ok, []} =
               Offers.list_discoverable(context.wholesaler_actor, context.wholesaler.id)

      assert {:ok, [%{offer: %{id: id}}]} =
               Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      assert id == published.id
    end
  end

  describe "get_discoverable/3" do
    test "returns the offer with :none when no connection exists", context do
      published = publish_offer!(context)

      assert {:ok, %{offer: offer, connection_status: :none}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      assert offer.id == published.id
    end

    test "reports :pending and :connected connection states", context do
      published = publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      assert {:ok, %{connection_status: :pending}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      {:ok, _} = Network.approve(context.wholesaler_actor, conn)

      assert {:ok, %{connection_status: :connected}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)
    end

    test "reports :unavailable for a rejected prior connection", context do
      published = publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      {:ok, _rejected} = Network.reject(context.wholesaler_actor, conn, "Not a fit right now")

      assert {:ok, %{connection_status: :unavailable}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)
    end

    test "reports :unavailable for a suspended prior connection", context do
      published = publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      {:ok, active} = Network.approve(context.wholesaler_actor, conn)
      {:ok, _suspended} = Network.suspend(context.wholesaler_actor, active, "Quality issues")

      assert {:ok, %{connection_status: :unavailable}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)
    end

    test "is :not_found for paused offers and the store's own offers", context do
      published = publish_offer!(context)
      {:ok, _} = Offers.pause(context.wholesaler_actor, published)

      assert {:error, :not_found} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      republished =
        publish_offer!(context, product: context.product_2, variant: context.variant_2)

      assert {:error, :not_found} =
               Offers.get_discoverable(
                 context.wholesaler_actor,
                 context.wholesaler.id,
                 republished.id
               )
    end
  end
end
