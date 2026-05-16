defmodule Emakola.Fulfillment.Dispatcher do
  @moduledoc """
  Routes a line item to the correct fulfillment pipeline based on its
  `:product_type`. Every product type listed in the `Emakola.Catalog.Product`
  `one_of` constraint must have an entry in `@pipelines`; the lockstep test
  in `Emakola.Fulfillment.DispatcherTest` will fail if the two drift.

  This is the single switchboard the order pipeline calls after payment
  confirms — it's intentionally thin so that adding a new product type
  means adding one entry here and one new pipeline module, with no
  conditionals scattered through checkout.
  """

  alias Emakola.Fulfillment.Pipelines

  @pipelines %{
    physical: Pipelines.Physical,
    digital_download: Pipelines.DigitalDownload,
    license_key: Pipelines.LicenseKey,
    streaming: Pipelines.Streaming,
    course: Pipelines.Course,
    auction: Pipelines.Auction,
    print_on_demand: Pipelines.PrintOnDemand
  }

  @type product_type :: atom()

  @spec dispatch(product_type, map(), map()) :: Emakola.Fulfillment.Pipeline.result()
  def dispatch(product_type, line_item, context \\ %{}) when is_atom(product_type) do
    case Map.fetch(@pipelines, product_type) do
      {:ok, pipeline} -> pipeline.fulfill(line_item, context)
      :error -> {:error, {:unknown_product_type, product_type}}
    end
  end

  @spec pipeline_for(product_type) :: module() | nil
  def pipeline_for(product_type) when is_atom(product_type) do
    Map.get(@pipelines, product_type)
  end

  @spec supported_types() :: [product_type]
  def supported_types, do: Map.keys(@pipelines)
end
