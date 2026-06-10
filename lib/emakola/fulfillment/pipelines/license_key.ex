defmodule Emakola.Fulfillment.Pipelines.LicenseKey do
  @moduledoc """
  Fulfillment pipeline for `:license_key` products (Phase 2). Will draw a
  key from the merchant's key pool (or generate one for managed products),
  mark it issued, and deliver it via the order confirmation channel.
  Skeleton — currently returns `{:ok, :deferred}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:ok, :deferred}
end
