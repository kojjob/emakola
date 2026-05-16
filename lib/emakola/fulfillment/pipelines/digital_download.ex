defmodule Emakola.Fulfillment.Pipelines.DigitalDownload do
  @moduledoc """
  Fulfillment pipeline for `:digital_download` products (Phase 1). Will issue
  signed, expiring download URLs against S3-compatible storage and persist
  the grant so merchants can revoke or re-issue. Skeleton — currently
  returns `{:error, :not_implemented}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:error, :not_implemented}
end
