defmodule Emakola.Suppliers.GhanaRegions do
  @moduledoc """
  Canonical delivery-area names for supplier offers. Using one fixed list
  keeps `dispatch_fees` keys consistent across suppliers (the DispatchFees
  validation requires fee keys ⊆ delivery_areas, and future filtering by
  area depends on exact string equality).
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
end
