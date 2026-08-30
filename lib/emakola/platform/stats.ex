defmodule Emakola.Platform.Stats do
  @moduledoc "Platform-wide aggregate statistics for the admin dashboard."
  require Ash.Query
  require Logger

  def total_stores do
    Emakola.Stores.Store
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc """
  Stores the marketplace actually serves.

  Both switches, not one. `active` is the merchant's own open/closed flag;
  `status` is the platform's, and archiving or suspending a store leaves
  `active` untouched. Counting only the merchant flag reported stores that no
  longer appear anywhere public — the tile read 41 while /stores served 39,
  sitting beside a "total stores" of 41 and so implying every store was
  healthy.

  `total_stores/0` still counts everything on purpose: the platform's own
  records should not lose a store because it was archived.
  """
  def active_stores do
    Emakola.Stores.Store
    |> Ash.Query.filter(active == true and status == :active)
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

  def refund_count do
    Emakola.Payments.Payment
    |> Ash.Query.filter(status == :refunded)
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, count} -> count
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
         |> Ash.Query.filter(status == :refunded)
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
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, results} ->
        results

      {:error, error} ->
        Logger.error("[Platform.Stats] recent_by_status/2 failed: #{inspect(error)}")
        []
    end
  end

  # ── Time series for the platform overview charts ────────────────────
  # Fetched rows are bucketed in Elixir — fine at current volume; move to
  # a grouped SQL aggregate when payment counts warrant it.

  @doc "Successful-payment GMV (minor units) per day, oldest first, gaps filled."
  def gmv_by_day(days \\ 30) do
    today = Date.utc_today()
    start_date = Date.add(today, -(days - 1))
    {:ok, start_dt} = DateTime.new(start_date, ~T[00:00:00], "Etc/UTC")

    payments =
      case Emakola.Payments.Payment
           |> Ash.Query.filter(status == :success and inserted_at >= ^start_dt)
           |> Ash.read(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    by_day = Enum.group_by(payments, &DateTime.to_date(&1.inserted_at))

    buckets =
      Enum.map(Date.range(start_date, today), fn date ->
        total = by_day |> Map.get(date, []) |> Enum.map(& &1.amount) |> Enum.sum()
        {Calendar.strftime(date, "%b %d"), total}
      end)

    %{labels: Enum.map(buckets, &elem(&1, 0)), values: Enum.map(buckets, &elem(&1, 1))}
  end

  @doc "New stores per calendar week, oldest first, gaps filled."
  def new_stores_by_week(weeks \\ 8) do
    this_week = Date.beginning_of_week(Date.utc_today())
    start_week = Date.add(this_week, -7 * (weeks - 1))
    {:ok, start_dt} = DateTime.new(start_week, ~T[00:00:00], "Etc/UTC")

    stores =
      case Emakola.Stores.Store
           |> Ash.Query.filter(inserted_at >= ^start_dt)
           |> Ash.read(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    by_week =
      Enum.group_by(stores, fn store ->
        store.inserted_at |> DateTime.to_date() |> Date.beginning_of_week()
      end)

    buckets =
      Enum.map(0..(weeks - 1), fn offset ->
        week = Date.add(start_week, offset * 7)
        {Calendar.strftime(week, "%b %d"), length(Map.get(by_week, week, []))}
      end)

    %{labels: Enum.map(buckets, &elem(&1, 0)), values: Enum.map(buckets, &elem(&1, 1))}
  end
end
