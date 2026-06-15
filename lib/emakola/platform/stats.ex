defmodule Emakola.Platform.Stats do
  @moduledoc "Platform-wide aggregate statistics for the admin dashboard."
  require Ash.Query

  def total_stores do
    Emakola.Stores.Store
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def active_stores do
    Emakola.Stores.Store
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
    Emakola.Stores.Store
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

  # ── Payment aggregations (cross-store via global?(true)) ────────────

  def total_payments do
    case Ash.count(Emakola.Payments.Payment, authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  def successful_payment_count, do: count_by_status(:success)
  def failed_payment_count, do: count_by_status(:failed)

  defp count_by_status(status) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(status == ^status)
         |> Ash.count(authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  def total_refunded do
    case Emakola.Payments.Payment
         |> Ash.sum(:refunded_amount, authorize?: false) do
      {:ok, s} -> s || 0
      _ -> 0
    end
  end

  @payment_gateways [:paystack, :hubtel]

  def payment_gateway_breakdown do
    Map.new(@payment_gateways, fn gw -> {gw, gateway_stats(gw)} end)
  end

  defp gateway_stats(gw) do
    %{
      success_count: count_gateway(gw, :success),
      failed_count: count_gateway(gw, :failed),
      success_volume: sum_gateway_success(gw)
    }
  end

  defp count_gateway(gw, status) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(gateway == ^gw and status == ^status)
         |> Ash.count(authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp sum_gateway_success(gw) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(gateway == ^gw and status == :success)
         |> Ash.sum(:amount, authorize?: false) do
      {:ok, s} -> s || 0
      _ -> 0
    end
  end

  def recent_failed_payments(limit \\ 20), do: recent_by_status(:failed, limit)
  def recent_refunded_payments(limit \\ 10), do: recent_by_status(:refunded, limit)

  defp recent_by_status(status, limit) do
    Emakola.Payments.Payment
    |> Ash.Query.filter(status == ^status)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.load([:store])
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end
end
