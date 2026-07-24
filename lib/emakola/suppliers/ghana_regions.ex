defmodule Emakola.Suppliers.GhanaRegions do
  @moduledoc """
  Canonical delivery-area names for supplier offers. Using one fixed list
  keeps `dispatch_fees` keys consistent across suppliers (the DispatchFees
  validation requires fee keys ⊆ delivery_areas, and future filtering by
  area depends on exact string equality).

  Provides functions to canonicalize region names and generate select options
  with snake_case parameters.
  """

  @regions [
    "Greater Accra",
    "Ashanti",
    "Western",
    "Western North",
    "Central",
    "Eastern",
    "Volta",
    "Oti",
    "Northern",
    "Savannah",
    "North East",
    "Upper East",
    "Upper West",
    "Bono",
    "Bono East",
    "Ahafo"
  ]

  @spec all() :: [String.t()]
  def all, do: @regions

  @doc """
  Canonicalize a snake_case parameter to the canonical region name.

  Returns the canonical region name (e.g., "Greater Accra") if the param matches,
  or nil if it doesn't match or the input is not a binary.

  ## Examples

      iex> from_param("greater_accra")
      "Greater Accra"

      iex> from_param("bono_east")
      "Bono East"

      iex> from_param("other")
      nil

      iex> from_param("atlantis")
      nil

      iex> from_param(nil)
      nil
  """
  @spec from_param(term()) :: String.t() | nil
  def from_param(param) when is_binary(param) do
    Enum.find(@regions, fn region -> param_for(region) == param end)
  end

  def from_param(_), do: nil

  @doc """
  Convert a canonical region name to a snake_case parameter.

  Downcases the name and replaces spaces with underscores.

  ## Examples

      iex> param_for("Greater Accra")
      "greater_accra"

      iex> param_for("Western North")
      "western_north"
  """
  @spec param_for(String.t()) :: String.t()
  def param_for(region), do: region |> String.downcase() |> String.replace(" ", "_")

  @doc """
  Get all 16 regions plus "Other" as select options.

  Returns a list of `{label, param}` tuples suitable for use in an HTML select.
  The canonical region names are labels, and snake_case params are values.
  Appends "Other" as the final option.

  ## Examples

      iex> select_options()
      [
        {"Greater Accra", "greater_accra"},
        {"Ashanti", "ashanti"},
        # ... 14 more regions ...
        {"Other", "other"}
      ]
  """
  @spec select_options() :: [{String.t(), String.t()}]
  def select_options, do: Enum.map(@regions, &{&1, param_for(&1)}) ++ [{"Other", "other"}]
end
