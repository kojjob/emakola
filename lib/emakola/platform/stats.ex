defmodule Emakola.Platform.Stats do
  @moduledoc "Platform-wide aggregate statistics for the admin dashboard."
  require Ash.Query

  def total_stores do
    Emakola.Accounts.Store
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def active_stores do
    Emakola.Accounts.Store
    |> Ash.Query.filter(active == true)
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def total_merchants do
    Emakola.Accounts.Merchant
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def total_orders do
    Emakola.Orders.Order
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def total_gmv do
    # Sum of all successful payment amounts (in minor units)
    case Emakola.Payments.Payment
         |> Ash.Query.filter(status == :success)
         |> Ash.sum(:amount, authorize?: false) do
      {:ok, sum} -> sum || 0
      _ -> 0
    end
  end

  def total_products do
    Emakola.Catalog.Product
    |> Ash.Query.filter(status == :active)
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def total_customers do
    Emakola.Customers.Customer
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def recent_stores(limit \\ 10) do
    Emakola.Accounts.Store
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(authorize?: false)
  end

  def recent_merchants(limit \\ 10) do
    Emakola.Accounts.Merchant
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(authorize?: false)
  end
end
