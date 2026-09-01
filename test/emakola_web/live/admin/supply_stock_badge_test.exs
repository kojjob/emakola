defmodule EmakolaWeb.Admin.SupplyStockBadgeTest do
  @moduledoc """
  Task 4 (supplier-stock-truth): reseller-facing supplier-stock badges
  (In stock / Low stock / Out of stock) across the three supply surfaces —
  the offers tab and listings tab on `/admin/settings/supply-network`, and
  the offer detail page at `/admin/supply/catalog/:offer_id`. Badges are
  status only, computed from `EmakolaWeb.Live.Admin.SupplyStockStatus.aggregate/1`
  over the offer's/listing's SOURCE variants — the supplier's raw stock
  quantity must never appear in reseller-facing markup.
  """

  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.{ListingImporter, Network, Offers}
  alias EmakolaWeb.Live.Admin.SupplyStockStatus

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Stock Wholesaler"})

    %{
      conn: conn,
      merchant: merchant,
      store: store,
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler
    }
  end

  describe "SupplyStockStatus.aggregate/1" do
    test "all :out source variants aggregate to :out" do
      variants = [
        %{track_inventory: true, stock_quantity: 0},
        %{track_inventory: true, stock_quantity: 0}
      ]

      assert SupplyStockStatus.aggregate(variants) == :out
    end

    test "a mix of :low and :in_stock aggregates to :low" do
      variants = [
        %{track_inventory: true, stock_quantity: 5},
        %{track_inventory: true, stock_quantity: 20}
      ]

      assert SupplyStockStatus.aggregate(variants) == :low
    end

    test "a mix of :out and :in_stock aggregates to :in_stock" do
      variants = [
        %{track_inventory: true, stock_quantity: 0},
        %{track_inventory: true, stock_quantity: 20}
      ]

      assert SupplyStockStatus.aggregate(variants) == :in_stock
    end
  end

  describe "offers tab" do
    # Draining ALL variants to zero is not exercised here: a fully
    # out-of-stock offer fails `Offers.discoverable?/1` (pre-existing
    # behaviour — `Enum.any?(offer_variants, &source_available?/1)`) and
    # drops out of `list_available/2` entirely, so its card — and thus its
    # badge — would no longer be on the page at all. The "Out of stock"
    # badge is exercised on the listings tab below, where an already
    # imported listing keeps showing regardless of current source stock.
    test "renders the aggregated supplier-stock badge, tracking source stock across states",
         ctx do
      %{offer: offer, variant_b: variant_b} = publish_two_variant_offer!(ctx, 20, 20)

      connect!(ctx)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
      assert badge_html(view, "#offer-stock-badge-#{offer.id}") =~ "In stock"

      set_stock!(variant_b, 5)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
      assert badge_html(view, "#offer-stock-badge-#{offer.id}") =~ "Low stock"
    end

    test "never leaks the supplier's raw stock quantity in the badge", ctx do
      %{offer: offer} = publish_two_variant_offer!(ctx, 8, 20)
      connect!(ctx)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

      refute badge_html(view, "#offer-stock-badge-#{offer.id}") =~ ~r/\b8\b/
    end
  end

  describe "listings tab" do
    test "renders the aggregated supplier-stock badge, tracking source stock across states",
         ctx do
      %{offer: offer, variant_a: variant_a, variant_b: variant_b} =
        publish_two_variant_offer!(ctx, 20, 20)

      connect!(ctx)
      {:ok, listing} = ListingImporter.import(ctx.merchant, ctx.store.id, offer)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
      assert badge_html(view, "#listing-stock-badge-#{listing.id}") =~ "In stock"

      set_stock!(variant_b, 5)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
      assert badge_html(view, "#listing-stock-badge-#{listing.id}") =~ "Low stock"

      set_stock!(variant_a, 0)
      set_stock!(variant_b, 0)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")
      assert badge_html(view, "#listing-stock-badge-#{listing.id}") =~ "Out of stock"
    end

    test "never leaks the supplier's raw stock quantity in the badge", ctx do
      %{offer: offer} = publish_two_variant_offer!(ctx, 8, 20)
      connect!(ctx)
      {:ok, listing} = ListingImporter.import(ctx.merchant, ctx.store.id, offer)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network/tools")

      refute badge_html(view, "#listing-stock-badge-#{listing.id}") =~ ~r/\b8\b/
    end
  end

  describe "catalog show page" do
    test "renders the aggregated supplier-stock badge for the offer", ctx do
      %{offer: offer} = publish_two_variant_offer!(ctx, 20, 20)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/supply/catalog/#{offer.id}")

      assert badge_html(view, "#offer-stock-badge") =~ "In stock"
    end

    test "never leaks the supplier's raw stock quantity in the badge", ctx do
      %{offer: offer} = publish_two_variant_offer!(ctx, 8, 20)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/supply/catalog/#{offer.id}")

      refute badge_html(view, "#offer-stock-badge") =~ ~r/\b8\b/
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp publish_two_variant_offer!(ctx, stock_a, stock_b) do
    product = create_product!(ctx.wholesaler, status: :active, title: "Kente sandals")

    variant_a =
      create_variant!(product, ctx.wholesaler,
        price: 6_000,
        sku: "STOCK-A-#{System.unique_integer([:positive])}",
        stock_quantity: stock_a
      )

    variant_b =
      create_variant!(product, ctx.wholesaler,
        price: 6_500,
        sku: "STOCK-B-#{System.unique_integer([:positive])}",
        stock_quantity: stock_b
      )

    {:ok, offer} =
      Offers.create_draft(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, _terms_a} =
      Offers.add_variant(ctx.wholesaler_actor, offer, %{
        source_variant_id: variant_a.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, _terms_b} =
      Offers.add_variant(ctx.wholesaler_actor, offer, %{
        source_variant_id: variant_b.id,
        supplier_price: 4_500,
        suggested_retail_price: 5_500,
        max_retail_price: 6_200
      })

    {:ok, published} = Offers.publish(ctx.wholesaler_actor, offer)

    %{offer: published, variant_a: variant_a, variant_b: variant_b}
  end

  defp connect!(ctx) do
    {:ok, pending} =
      Network.request(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.wholesaler.id
      })

    {:ok, _active} = Network.approve(ctx.merchant, pending)
    :ok
  end

  defp set_stock!(variant, quantity) do
    fresh = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

    fresh
    |> Ash.Changeset.for_update(:adjust_stock, %{delta: quantity - fresh.stock_quantity})
    |> Ash.update!(authorize?: false)
  end

  defp badge_html(view, selector), do: view |> element(selector) |> render()
end
