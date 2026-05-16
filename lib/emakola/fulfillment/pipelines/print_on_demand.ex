defmodule Emakola.Fulfillment.Pipelines.PrintOnDemand do
  @moduledoc """
  Fulfillment pipeline for `:print_on_demand` products (Phase 7). Will
  submit the order to the configured POD vendor (Printful / Printify /
  local partner), persist the vendor's reference, and forward tracking
  updates back to the buyer. Skeleton — currently returns
  `{:error, :not_implemented}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:error, :not_implemented}
end
