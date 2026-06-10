defmodule Emakola.Fulfillment.Pipelines.Course do
  @moduledoc """
  Fulfillment pipeline for `:course` products (Phase 5). Will enroll the
  buyer into the course, create their progress record, and trigger the
  welcome / first-lesson notification. Skeleton — currently returns
  `{:ok, :deferred}`.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  @impl true
  def fulfill(_line_item, _context), do: {:ok, :deferred}
end
