defmodule Emakola.Analytics.StoreVisitPagesTest do
  @moduledoc """
  Visits were counted on the shop home page only. WhatsApp and Instagram
  links land on product pages, so the traffic sellers drive was uncounted
  and conversion read higher than it was.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Analytics.StoreVisits

  setup do
    store = create_store!()
    product = create_product!(store)
    {:ok, store: store, product: product}
  end

  test "a product page visit carries the page and the product", %{store: store, product: product} do
    {:ok, visit} =
      StoreVisits.record(store.id, "s1", %{"page" => :product, "product_id" => product.id})

    assert visit.page == :product
    assert visit.product_id == product.id
  end

  test "a visit with no page is the home page", %{store: store} do
    {:ok, visit} = StoreVisits.record(store.id, "s1", %{})
    assert visit.page == :home
  end

  test "visitors between two instants, whatever page they saw", %{store: store, product: product} do
    StoreVisits.record(store.id, "s1", %{})
    StoreVisits.record(store.id, "s1", %{"page" => :product, "product_id" => product.id})
    StoreVisits.record(store.id, "s2", %{"page" => :pay_link})

    from = DateTime.add(DateTime.utc_now(), -60, :second)
    to = DateTime.add(DateTime.utc_now(), 60, :second)

    assert StoreVisits.visitors_between(store.id, from, to) == 2
  end

  test "product visitors per product", %{store: store, product: product} do
    other = create_product!(store)
    StoreVisits.record(store.id, "s1", %{"page" => :product, "product_id" => product.id})
    StoreVisits.record(store.id, "s1", %{"page" => :product, "product_id" => product.id})
    StoreVisits.record(store.id, "s2", %{"page" => :product, "product_id" => product.id})
    StoreVisits.record(store.id, "s3", %{"page" => :product, "product_id" => other.id})

    from = DateTime.add(DateTime.utc_now(), -60, :second)
    to = DateTime.add(DateTime.utc_now(), 60, :second)

    assert StoreVisits.product_visitors(store.id, from, to) == %{product.id => 2, other.id => 1}
  end

  test "another store's product visitors never appear in this store's counts", %{
    store: store,
    product: product
  } do
    elsewhere = create_store!()
    elsewhere_product = create_product!(elsewhere)

    StoreVisits.record(store.id, "s1", %{"page" => :product, "product_id" => product.id})

    StoreVisits.record(elsewhere.id, "s2", %{
      "page" => :product,
      "product_id" => elsewhere_product.id
    })

    from = DateTime.add(DateTime.utc_now(), -60, :second)
    to = DateTime.add(DateTime.utc_now(), 60, :second)

    assert StoreVisits.product_visitors(store.id, from, to) == %{product.id => 1}
    assert StoreVisits.visitors_between(store.id, from, to) == 1
  end
end
