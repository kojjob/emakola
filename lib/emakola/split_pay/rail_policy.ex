defmodule Emakola.SplitPay.RailPolicy do
  @moduledoc """
  Resolves which settlement rail a charge routes down.

  Resolution order: an explicit `rail:` option (callers and async tests),
  then the per-store `gateway_rail_store_ids` pin list, then the configured
  `default_rail`, then `:internal_first`. The pin list keeps individual
  stores on automatic gateway settlement without a schema change; everything
  else is one config value, so the production flip (and its rollback) is a
  secret change, not a deploy.
  """

  @rails [:gateway_first, :internal_first]

  @spec rail(term(), keyword()) :: :gateway_first | :internal_first
  def rail(store_id, opts \\ []) do
    opts
    |> Keyword.get_lazy(:rail, fn -> configured_rail(store_id) end)
    |> validate!()
  end

  defp configured_rail(store_id) do
    config = Application.get_env(:emakola, Emakola.SplitPay, [])

    if store_id in Keyword.get(config, :gateway_rail_store_ids, []) do
      :gateway_first
    else
      Keyword.get(config, :default_rail, :internal_first)
    end
  end

  defp validate!(rail) when rail in @rails, do: rail

  defp validate!(other) do
    raise ArgumentError,
          "unknown settlement rail #{inspect(other)} — expected one of #{inspect(@rails)}"
  end
end
