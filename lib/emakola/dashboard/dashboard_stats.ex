defmodule Emakola.Dashboard.Stats do
  @moduledoc """
  Dashboard statistics for the merchant admin panel.

  Computes key metrics for a given store: revenue, order counts,
  product counts, customer counts, recent orders, low stock alerts,
  and top products. All queries are scoped to the store's `store_id`.
  """

  require Ash.Query
  import Ecto.Query, only: [from: 2]

  alias Emakola.AsyncSandbox

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
    # Each query hits an independent table (payments / orders / products /
    # customers / variants); they don't depend on each other so we run them
    # concurrently. With 7 sequential ~50ms queries the dashboard mount
    # blocked for ~350ms; in parallel it's bounded by the slowest single
    # query (~50–100ms). Each task gets a fresh DB connection from the
    # pool — load_stats/1 is called from the dashboard LV mount which
    # already runs in its own process.
    tasks = [
      AsyncSandbox.run_async(fn -> {:total_revenue, calculate_revenue(store_id)} end),
      AsyncSandbox.run_async(fn -> {:order_count, count_orders(store_id)} end),
      AsyncSandbox.run_async(fn -> {:active_products, count_active_products(store_id)} end),
      AsyncSandbox.run_async(fn -> {:customer_count, count_customers(store_id)} end),
      AsyncSandbox.run_async(fn -> {:recent_orders, recent_orders(store_id, 10)} end),
      AsyncSandbox.run_async(fn ->
        {:low_stock, low_stock_variants(store_id, @low_stock_threshold)}
      end),
      AsyncSandbox.run_async(fn -> {:top_products, top_products(store_id, 5)} end)
    ]

    tasks
    |> Task.await_many(10_000)
    |> Map.new()
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

  @doc """
  Returns variants below the stock threshold that track inventory.

  Delegates to `Emakola.Inventory.list_low_stock/2` — the dashboard
  is one of several callers (alongside the inventory page and
  low-stock alert worker) for the same query, so the canonical
  implementation lives in the Inventory context.
  """
  def low_stock_variants(store_id, threshold) do
    Emakola.Inventory.list_low_stock(store_id, threshold)
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

  @doc """
  Returns the top-5 products by units sold in the given datetime window,
  formatted as `%{labels: [String.t()], values: [non_neg_integer()]}` for
  chart rendering.

  Query is scoped to `store_id` via the WHERE clause on `li.store_id`.
  Product titles are truncated to 20 characters to fit chart labels.
  """
  @spec top_line_items_chart(Ash.UUID.t(), DateTime.t(), DateTime.t()) ::
          %{labels: [String.t()], values: [non_neg_integer()]}
  def top_line_items_chart(store_id, from, to) do
    query =
      from li in Emakola.Orders.LineItem,
        where:
          li.store_id == ^store_id and
            li.inserted_at >= ^from and
            li.inserted_at < ^to,
        group_by: li.product_title,
        order_by: [desc: sum(li.quantity)],
        limit: 5,
        select: {fragment("LEFT(?, 20)", li.product_title), sum(li.quantity)}

    results = Emakola.Repo.all(query)

    labels = Enum.map(results, fn {title, _qty} -> title end)

    values =
      Enum.map(results, fn {_title, qty} ->
        if is_struct(qty, Decimal), do: Decimal.to_integer(qty), else: qty || 0
      end)

    %{labels: labels, values: values}
  end

  @doc """
  Returns the best-selling products in the range as
  `[%{title:, quantity:, image_url:}]`, most sold first.

  Grouped by `variant_id` rather than the denormalized `product_title` so each
  row can carry its product photo — merchants recognize their stock by picture
  before they read the name. Custom line items (no variant) are excluded:
  there is no product record behind them to show.
  """
  def best_sellers(store_id, from, to, limit \\ 4) do
    query =
      from li in Emakola.Orders.LineItem,
        where:
          li.store_id == ^store_id and
            li.inserted_at >= ^from and
            li.inserted_at < ^to and
            not is_nil(li.variant_id),
        group_by: li.variant_id,
        order_by: [desc: sum(li.quantity)],
        limit: ^limit,
        select: {li.variant_id, sum(li.quantity)}

    results = Emakola.Repo.all(query)
    products = variant_products(Enum.map(results, fn {variant_id, _} -> variant_id end))

    Enum.map(results, fn {variant_id, quantity} ->
      product = Map.get(products, variant_id, %{title: "Product", image_url: nil})

      %{
        title: product.title,
        quantity: to_integer(quantity),
        image_url: product.image_url
      }
    end)
  end

  defp to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  defp to_integer(value), do: value || 0

  defp variant_products([]), do: %{}

  defp variant_products(variant_ids) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(id in ^variant_ids)
         |> Ash.Query.load(product: [:images])
         |> Ash.read(authorize?: false) do
      {:ok, variants} ->
        Map.new(variants, fn variant ->
          {variant.id,
           %{
             title: variant.product && variant.product.title,
             image_url: first_image_url(variant.product)
           }}
        end)

      _ ->
        %{}
    end
  end

  defp first_image_url(%{images: [image | _]}), do: image.thumbnail_url || image.url
  defp first_image_url(_product), do: nil
end
