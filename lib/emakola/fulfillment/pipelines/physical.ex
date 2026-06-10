defmodule Emakola.Fulfillment.Pipelines.Physical do
  @moduledoc """
  Fulfillment pipeline for `:physical` products. Will hand off to
  `Emakola.Shipping` for label generation, carrier booking, and tracking
  updates. Skeleton — currently returns `{:ok, :deferred}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:ok, :deferred}
end
