defmodule Emakola.Suppliers.RadarEvaluation do
  @moduledoc """
  Controlled-evaluation harness for the Opportunity Radar (income-OS Phase C).

  Stores are split into two arms by a pure hash of their id: the `:radar` arm
  sees the radar's blended ranking, the `:popularity` arm sees a
  popularity-only baseline (order count). Because assignment is a deterministic
  function of `store_id`, outcomes already recorded by the conversion ledger
  attribute to an arm with no exposure logging or new analytics infrastructure.

  The exit criterion (radar beats popularity in fulfilled sales without
  increasing refunds) needs real pilot traffic; `mix emakola.radar_eval`
  prints the running comparison.
  """

  require Ash.Query

  alias Emakola.Suppliers.{SalesShareConversion, SalesSharing}

  @doc "Deterministic evaluation arm for a store."
  def arm(store_id) do
    :md5
    |> :crypto.hash(to_string(store_id))
    |> :binary.first()
    |> rem(2)
    |> case do
      0 -> :radar
      1 -> :popularity
    end
  end

  @doc """
  Orders radar entries per the store's arm. The `:radar` arm keeps the blended
  order produced by `OpportunityRadar.build/5`; the `:popularity` arm re-ranks
  purely by order count — deliberately blind to demand signals, freshness,
  and fulfillment quality.
  """
  def rank(entries, store_id) do
    case arm(store_id) do
      :radar -> entries
      :popularity -> Enum.sort_by(entries, &{-&1.orders, &1.title})
    end
  end

  @doc "Builds outcome rows from the conversion ledger and summarizes them per arm."
  def report do
    SalesShareConversion
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(& &1.store_id)
    |> Enum.flat_map(fn {store_id, conversions} ->
      conversions
      |> Ash.load!([order: :fulfillments], authorize?: false, tenant: store_id)
      |> Enum.map(fn conversion ->
        %{
          store_id: conversion.store_id,
          revenue: conversion.revenue,
          delivered?: SalesSharing.delivered_conversion?(conversion),
          refunded?: refunded?(conversion)
        }
      end)
    end)
    |> summarize()
  end

  @doc "Aggregates outcome rows (`%{store_id, revenue, delivered?, refunded?}`) per arm."
  def summarize(rows) do
    grouped = Enum.group_by(rows, &arm(&1.store_id))

    %{
      radar: side(Map.get(grouped, :radar, [])),
      popularity: side(Map.get(grouped, :popularity, []))
    }
  end

  defp side(rows) do
    delivered = Enum.filter(rows, & &1.delivered?)

    %{
      stores: rows |> Enum.map(& &1.store_id) |> Enum.uniq() |> length(),
      orders: length(rows),
      fulfilled: length(delivered),
      refunded: Enum.count(rows, & &1.refunded?),
      fulfilled_revenue: delivered |> Enum.map(& &1.revenue) |> Enum.sum()
    }
  end

  defp refunded?(conversion) do
    case Emakola.Payments.get_payment_by_order(conversion.order_id, authorize?: false) do
      {:ok, payment} -> payment.refunded_amount > 0
      _error -> false
    end
  end
end
