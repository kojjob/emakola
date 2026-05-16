defmodule Emakola.Fulfillment.Pipelines.Auction do
  @moduledoc """
  Fulfillment pipeline for `:auction` products (Phases 3 and 4). Used after
  an auction settles into an order — converts the winning bid into a
  fulfillable line item, then delegates to the underlying physical /
  digital fulfillment path depending on the lot. Skeleton — currently
  returns `{:error, :not_implemented}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:error, :not_implemented}
end
