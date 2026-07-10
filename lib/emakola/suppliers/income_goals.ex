defmodule Emakola.Suppliers.IncomeGoals do
  @moduledoc "Authorized service boundary for reseller income goals."

  require Ash.Query
  alias Emakola.Suppliers.IncomeGoal

  def create(actor, store_id, attrs) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, normalized} <- normalize(attrs) do
      IncomeGoal
      |> Ash.Changeset.for_create(:create, Map.put(normalized, :store_id, store_id))
      |> Ash.create(authorize?: false)
    end
  end

  def list(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      Emakola.Suppliers.list_income_goals_for_store(store_id, authorize?: false)
    end
  end

  def active(actor, store_id) do
    with {:ok, goals} <- list(actor, store_id) do
      {:ok, Enum.find(goals, &(&1.status == :active))}
    end
  end

  defp normalize(attrs) do
    with {:ok, target} <- positive_integer(attrs[:target_amount] || attrs["target_amount"]),
         {:ok, days} <- bounded_integer(attrs[:timeframe_days] || attrs["timeframe_days"], 7, 90),
         {:ok, minutes} <-
           bounded_integer(attrs[:daily_minutes] || attrs["daily_minutes"], 10, 480) do
      starts_on = Date.utc_today()

      {:ok,
       %{
         target_amount: target,
         timeframe_days: days,
         daily_minutes: minutes,
         channels: normalize_channels(attrs[:channels] || attrs["channels"] || []),
         starts_on: starts_on,
         ends_on: Date.add(starts_on, days - 1)
       }}
    end
  end

  defp positive_integer(value), do: bounded_integer(value, 1, 100_000_000_000)

  defp bounded_integer(value, min, max) when is_integer(value) and value >= min and value <= max,
    do: {:ok, value}

  defp bounded_integer(value, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> bounded_integer(integer, min, max)
      _ -> {:error, :invalid_goal}
    end
  end

  defp bounded_integer(_value, _min, _max), do: {:error, :invalid_goal}

  defp normalize_channels(channels) when is_list(channels) do
    channels
    |> Enum.map(&channel/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_channels(_channels), do: []
  defp channel(value) when value in [:whatsapp, "whatsapp"], do: :whatsapp
  defp channel(value) when value in [:facebook, "facebook"], do: :facebook
  defp channel(value) when value in [:copy_link, "copy_link"], do: :copy_link
  defp channel(_value), do: nil

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
