defmodule Emakola.Orders.LineItemCustomTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.LineItem

  defp store_and_order do
    store = Emakola.Factory.create_store!()

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    {store, order}
  end

  test "create_custom builds a variant-less line with snapshots and line_total" do
    {store, order} = store_and_order()

    line =
      LineItem
      |> Ash.Changeset.for_create(:create_custom, %{
        order_id: order.id,
        store_id: store.id,
        product_title: "Custom kente dress — as agreed",
        unit_price: 25_000,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    assert line.variant_id == nil
    assert line.variant_sku == nil
    assert line.product_title == "Custom kente dress — as agreed"
    assert line.unit_price == 25_000
    assert line.line_total == 25_000
  end

  test "create_custom rejects a missing title" do
    {store, order} = store_and_order()

    assert {:error, %Ash.Error.Invalid{}} =
             LineItem
             |> Ash.Changeset.for_create(:create_custom, %{
               order_id: order.id,
               store_id: store.id,
               unit_price: 25_000,
               quantity: 1
             })
             |> Ash.create(authorize?: false)
  end

  test "create_custom rejects non-positive unit_price" do
    {store, order} = store_and_order()

    assert {:error, %Ash.Error.Invalid{}} =
             LineItem
             |> Ash.Changeset.for_create(:create_custom, %{
               order_id: order.id,
               store_id: store.id,
               product_title: "X",
               unit_price: 0,
               quantity: 1
             })
             |> Ash.create(authorize?: false)
  end

  test "confirming an order skips the custom line but still decrements the real variant's stock" do
    {store, order} = store_and_order()
    product = Emakola.Factory.create_product!(store)
    variant = Emakola.Factory.create_variant!(product, store, stock_quantity: 20)

    _real_line =
      LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 3
      })
      |> Ash.create!(authorize?: false)

    _custom_line =
      LineItem
      |> Ash.Changeset.for_create(:create_custom, %{
        order_id: order.id,
        store_id: store.id,
        product_title: "Custom kente dress — as agreed",
        unit_price: 25_000,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    assert {:ok, _confirmed} =
             order
             |> Ash.Changeset.for_update(:confirm, %{})
             |> Ash.update(authorize?: false)

    reloaded_variant = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
    assert reloaded_variant.stock_quantity == 17
  end
end
