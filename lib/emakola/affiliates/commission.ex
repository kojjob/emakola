defmodule Emakola.Affiliates.Commission do
  @moduledoc """
  Turns an attributed order into an affiliate's share of the money.

  Commission is a **carve**, not an append: it comes out of the merchant's
  allocation. `OrderSettlement.sum_matches_total?/2` is enforced on both
  rails, so an added allocation would make the whole charge unrepresentable
  and the payment would fail rather than the commission being skipped.

  Modelled on `Emakola.Suppliers.PartnerCredit.carve_sales_proceeds/2`, which
  is the existence proof that a third party can be paid through the ordinary
  split rail: everything downstream — the payable reads, refund netting,
  recovery, the payout claim, the MoMo transfer — is role-blind and keyed on
  `recipient_store_id`.

  ## What is checked before anyone is paid

  The token on an order is not evidence on its own. It arrives from a
  buyer's session, so before carving anything this re-derives what
  `SalesSharing.record_conversion/1` checks, because that is a different code
  path and cannot be relied on here:

    * the order contains the **product** the link promotes — otherwise an
      affiliate earns on whatever else the buyer happened to put in the cart
    * the link belongs to the **store** being settled — otherwise a token
      minted for one shop carves money out of another

  ## What the rate is a percentage OF

  The order total — what the buyer actually paid. A merchant who advertises
  "I pay 10%" means ten percent of the sale, and an affiliate who is told 10%
  of a GHS 100 order expects GHS 10. Computing on the merchant's *allocation*
  instead would quietly pay less, because the platform fee and any supplier
  cost come out first — and the shortfall would vary per order, which is
  worse than being lower: it is unexplainable.

  It is then **capped at what the merchant's allocation can bear**, so the
  row can never go negative (`finalize_internal` refuses the entire charge if
  it does). When the cap bites it is logged — a merchant whose margin cannot
  cover the rate they promised needs to know, and silence there becomes a
  dispute with the affiliate.

  This carve also runs BEFORE `PartnerCredit.carve_sales_proceeds/2`, so a
  credit repayment cannot consume the commission first. That is deliberate: a
  repayment is a schedule that catches up next order, while a commission is a
  promise to a third party who will simply stop promoting.
  """

  require Ash.Query
  require Logger

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme

  @carveable_roles [:merchant, :dropshipper]

  @doc """
  Returns `allocations` with commission carved out, or unchanged when nothing
  is owed.

  Never raises: a settlement path must not fail because an affiliate lookup
  did. An order that cannot be attributed simply pays nobody.
  """
  def carve(allocations, order) do
    with {:ok, link} <- attributed_link(order),
         true <- Programme.enabled?(link.store_id),
         {:ok, programme} <- Programme.get(link.store_id),
         true <- order_contains_product?(order, link.product_id),
         {:ok, affiliate} <- affiliate_for(link) do
      apply_carve(allocations, link, programme, affiliate, order)
    else
      _ -> allocations
    end
  rescue
    exception ->
      # A broken lookup must never take a payment down with it.
      Logger.error("[Affiliates] commission carve failed: #{inspect(exception)}")
      allocations
  end

  defp apply_carve(allocations, link, programme, affiliate, order) do
    Enum.flat_map(allocations, fn
      %{role: role, recipient_store_id: store_id, amount: amount} = allocation
      when role in @carveable_roles ->
        if store_id == link.store_id do
          split(allocation, amount, programme, affiliate, order)
        else
          [allocation]
        end

      allocation ->
        [allocation]
    end)
  end

  defp split(allocation, amount, programme, affiliate, order) do
    # Of the SALE — what the buyer paid — not of the merchant's allocation,
    # which the platform fee and supplier costs have already reduced.
    owed = div(max(order.total || 0, 0) * programme.commission_bps, 10_000)
    commission = min(owed, max(amount, 0))

    if commission < owed do
      Logger.info(
        "[Affiliates] commission capped store=#{programme.store_id} " <>
          "owed=#{owed} paid=#{commission} — another carve took the difference"
      )
    end

    if commission > 0 do
      [
        %{allocation | amount: amount - commission},
        %{
          role: :affiliate,
          recipient_store_id: affiliate.payout_store_id,
          amount: commission,
          # Explicit: default_settlement_method/1 returns :gateway_share for
          # every non-platform role, and an affiliate has no subaccount.
          settlement_method: :internal_hold,
          subaccount_code: nil,
          affiliate_id: affiliate.id
        }
      ]
    else
      [allocation]
    end
  end

  defp attributed_link(%{attribution: attribution}) when is_map(attribution) do
    case Map.get(attribution, "affiliate_token") || Map.get(attribution, :affiliate_token) do
      token when is_binary(token) and token != "" -> Programme.find_link(token)
      _ -> {:error, :not_attributed}
    end
  end

  defp attributed_link(_order), do: {:error, :not_attributed}

  defp affiliate_for(link) do
    case Ash.get(Affiliates.Affiliate, link.affiliate_id, authorize?: false) do
      {:ok, %{status: :active} = affiliate} -> {:ok, affiliate}
      _ -> {:error, :not_found}
    end
  end

  # The carve is a different code path from SalesSharing.record_conversion/1,
  # so the product check is re-derived here rather than assumed.
  defp order_contains_product?(order, product_id) do
    # Bound first: inside Ash.Query.filter, `^order.id` is parsed as pinning
    # the whole struct, and the query then compares a uuid column to an Order.
    order_id = order.id

    Emakola.Orders.LineItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load(:variant)
    |> Ash.read!(authorize?: false)
    |> Enum.any?(&(&1.variant && &1.variant.product_id == product_id))
  end
end
