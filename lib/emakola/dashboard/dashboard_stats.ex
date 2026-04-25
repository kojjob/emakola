defmodule Emakola.Dashboard.Stats do
  @moduledoc """
  Dashboard statistics for the merchant admin panel.

  Computes key metrics for a given store: revenue, order counts,
  product counts, customer counts, recent orders, low stock alerts,
  and top products. All queries are scoped to the store's `store_id`.
  """

  require Ash.Query

  @low_stock_threshold 10

  @doc """
  Loads all dashboard stats for a given store.

  Returns a map with:
  - total_revenue: sum of successful payment amounts (integer, minor units)
  - order_count: total number of orders
  - active_products: count of products with status :active
  - customer_count: total number of customers
  - recent_orders: last 10 orders sorted by date descending
  - low_stock: variants with stock_quantity < threshold and track_inventory == true
  - top_products: top 5 products by variant count
  """
  @spec load_stats(Ash.UUID.t()) :: map()
  def load_stats(store_id) do
    %{
      total_revenue: calculate_revenue(store_id),
      order_count: count_orders(store_id),
      active_products: count_active_products(store_id),
      customer_count: count_customers(store_id),
      recent_orders: recent_orders(store_id, 10),
      low_stock: low_stock_variants(store_id, @low_stock_threshold),
      top_products: top_products(store_id, 5)
    }
  end

  @doc "Sum of amounts for successful payments belonging to the store."
  def calculate_revenue(store_id) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(store_id == ^store_id and status == :success)
         |> Ash.Query.new()
         |> Ash.sum(:amount, authorize?: false) do
      {:ok, nil} -> 0
      {:ok, total} -> total
      _ -> 0
    end
  end

  @doc "Count of all orders belonging to the store."
  def count_orders(store_id) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(store_id == ^store_id)
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc "Count of products with status :active belonging to the store."
  def count_active_products(store_id) do
    case Emakola.Catalog.Product
         |> Ash.Query.filter(store_id == ^store_id and status == :active)
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc "Count of customers belonging to the store."
  def count_customers(store_id) do
    case Emakola.Customers.Customer
         |> Ash.Query.filter(store_id == ^store_id)
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc "Returns the latest `limit` orders for the store, sorted newest first."
  def recent_orders(store_id, limit) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(store_id == ^store_id)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(limit)
         |> Ash.Query.load(:customer)
         |> Ash.read(authorize?: false) do
      {:ok, orders} -> orders
      _ -> []
    end
  end

  @doc "Returns variants below the stock threshold that track inventory."
  def low_stock_variants(store_id, threshold) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(
           store_id == ^store_id and
             stock_quantity < ^threshold and
             track_inventory == true
         )
         |> Ash.Query.sort(stock_quantity: :asc)
         |> Ash.Query.limit(10)
         |> Ash.Query.load(:product)
         |> Ash.read(authorize?: false) do
      {:ok, variants} -> variants
      _ -> []
    end
  end

  @doc "Returns the top `limit` products by variant count, with aggregates loaded."
  def top_products(store_id, limit) do
    case Emakola.Catalog.Product
         |> Ash.Query.filter(store_id == ^store_id)
         |> Ash.Query.load([:variant_count, :min_price, :max_price])
         |> Ash.Query.sort(variant_count: :desc)
         |> Ash.Query.limit(limit)
         |> Ash.read(authorize?: false) do
      {:ok, products} -> products
      _ -> []
    end
  end
end
