defmodule Emakola.Fulfillment.Pipeline do
  @moduledoc """
  Behaviour every fulfillment pipeline implements.

  A pipeline owns the post-checkout work for a single `Emakola.Catalog.Product`
  `:product_type`: physical shipping, digital download issuance, license-key
  vending, streaming entitlement, course enrollment, auction settlement, or
  print-on-demand vendor handoff. `Emakola.Fulfillment.Dispatcher` routes work
  to the right pipeline based on the line item's product type.

  ## Callback contract

  `fulfill/2` receives a `line_item` map (or struct) and an opaque `context`
  map (currency, store, customer, etc.) and returns either `{:ok, result}` —
  where `result` describes what the pipeline did (e.g. a download grant,
  shipment label, license code) — or `{:error, reason}`.

  Skeleton pipelines return `{:error, :not_implemented}` until their phase
  ships, so callers can wire dispatch into the order flow today and get a
  recoverable error rather than a crash for types that aren't ready yet.
  """

  @type line_item :: map()
  @type context :: map()
  @type result :: {:ok, map() | :deferred} | {:error, term()}

  @callback fulfill(line_item, context) :: result
end
