defmodule Emakola.Fulfillment.Pipelines.Auction do
  @moduledoc """
  Fulfillment pipeline for `:auction` products (Phases 3 and 4). Used after
  an auction settles into an order — converts the winning bid into a
  fulfillable line item, then delegates to the underlying physical /
  digital fulfillment path depending on the lot. Skeleton — currently
  returns `{:ok, :deferred}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:ok, :deferred}
end
