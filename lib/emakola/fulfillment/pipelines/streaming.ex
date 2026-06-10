defmodule Emakola.Fulfillment.Pipelines.Streaming do
  @moduledoc """
  Fulfillment pipeline for `:streaming` products (Phase 6, Mux). Will grant
  the buyer playback entitlement on the asset and surface a signed playback
  URL with optional DRM. Skeleton — currently returns
  `{:ok, :deferred}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:ok, :deferred}
end
