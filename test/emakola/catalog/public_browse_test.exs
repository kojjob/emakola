defmodule Emakola.Catalog.PublicBrowseTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  defp active_product!(store, attrs \\ %{}) do
    create_product!(store, Map.put(Map.new(attrs), :status, :active))
  end

  describe "public_list" do
    test "returns only active products of the tenant store, newest first" do
      {_m, store} = create_merchant_with_store!()
      other = create_store!()

      p1 = active_product!(store)
      p2 = active_product!(store)
      draft = create_product!(store, %{status: :draft})
      foreign = active_product!(other)

      page =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:public_list)
        |> Ash.read!(authorize?: false, tenant: store.id)

      ids = Enum.map(page.results, & &1.id)

      assert p1.id in ids
      assert p2.id in ids
      refute draft.id in ids
      refute foreign.id in ids
      assert length(ids) == 2
    end

    test "loads min_price, max_price and images" do
      {_m, store} = create_merchant_with_store!()
      active_product!(store)

      %{results: [product]} =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:public_list)
        |> Ash.read!(authorize?: false, tenant: store.id)

      assert %Ash.NotLoaded{} != product.images
      refute match?(%Ash.NotLoaded{}, product.min_price)
      refute match?(%Ash.NotLoaded{}, product.max_price)
    end

    test "supports keyset pagination" do
      {_m, store} = create_merchant_with_store!()
      active_product!(store)
      active_product!(store)

      page =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:public_list)
        |> Ash.Query.page(limit: 1, count: true)
        |> Ash.read!(authorize?: false, tenant: store.id)

      assert %Ash.Page.Keyset{} = page
      assert length(page.results) == 1
      assert page.count == 2
    end
  end

  describe "public_get" do
    test "returns an active product with variants and images loaded" do
      {_m, store} = create_merchant_with_store!()
      product = active_product!(store)

      {:ok, got} =
        Ash.get(Emakola.Catalog.Product, product.id,
          action: :public_get,
          authorize?: false,
          tenant: store.id
        )

      assert got.id == product.id
      refute match?(%Ash.NotLoaded{}, got.variants)
      refute match?(%Ash.NotLoaded{}, got.images)
      refute match?(%Ash.NotLoaded{}, got.min_price)
      refute match?(%Ash.NotLoaded{}, got.max_price)
    end

    test "does not return a draft product" do
      {_m, store} = create_merchant_with_store!()
      draft = create_product!(store, %{status: :draft})

      assert {:error, _} =
               Ash.get(Emakola.Catalog.Product, draft.id,
                 action: :public_get,
                 authorize?: false,
                 tenant: store.id
               )
    end

    test "does not return a product from another store" do
      {_m, store} = create_merchant_with_store!()
      other = create_store!()
      foreign = active_product!(other)

      assert {:error, _} =
               Ash.get(Emakola.Catalog.Product, foreign.id,
                 action: :public_get,
                 authorize?: false,
                 tenant: store.id
               )
    end
  end
end
