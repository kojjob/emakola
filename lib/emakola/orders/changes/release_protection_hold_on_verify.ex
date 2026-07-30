defmodule Emakola.Orders.Changes.ReleaseProtectionHoldOnVerify do
  @moduledoc """
  After a delivery OTP verifies, releases the order's buyer-protection hold
  (TC-2) — the strongest delivery signal available. Fires with reason
  `:delivery_otp`, but only once EVERY fulfillment on the order is delivered
  or OTP-verified (multi-fulfillment/dropship-split orders release
  together; v1 orders carry a single fulfillment).

  Runs `after_transaction`, not `after_action`, so the release's own reads
  (this fulfillment's order, its sibling fulfillments' `delivered/verified`
  state, the order's held payment) all see the just-committed `verified_at`
  rather than racing the enclosing transaction.

  A release failure — no hold, a frozen hold, a downstream error — is
  logged and swallowed here: it must never fail the OTP verification the
  buyer is standing in front of a courier waiting on.
  """

  use Ash.Resource.Change

  require Ash.Query
  require Logger

  alias Emakola.Orders.Fulfillment
  alias Emakola.Payments.ProtectionHolds

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, proof} = result ->
        release_if_all_delivered(proof)
        result

      _changeset, other ->
        other
    end)
  end

  defp release_if_all_delivered(proof) do
    fulfillment = Ash.get!(Fulfillment, proof.fulfillment_id, authorize?: false)

    if all_fulfillments_delivered?(fulfillment.order_id, fulfillment.store_id) do
      release(fulfillment)
    end
  rescue
    error ->
      Logger.error(
        "[delivery_otp] protection release lookup failed for proof=#{proof.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )
  end

  defp release(fulfillment) do
    case ProtectionHolds.release_for_order(
           fulfillment.order_id,
           fulfillment.store_id,
           :delivery_otp
         ) do
      :ok ->
        :ok

      {:error, error} ->
        Logger.error(
          "[delivery_otp] protection release failed for order=#{fulfillment.order_id}: " <>
            inspect(error)
        )
    end
  end

  defp all_fulfillments_delivered?(order_id, store_id) do
    Fulfillment
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load(:delivery_proof)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.all?(&delivered_or_verified?/1)
  end

  defp delivered_or_verified?(%Fulfillment{status: :delivered}), do: true

  defp delivered_or_verified?(%Fulfillment{delivery_proof: %{verified_at: verified_at}}),
    do: not is_nil(verified_at)

  defp delivered_or_verified?(_fulfillment), do: false
end
