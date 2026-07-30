defmodule Emakola.Orders.PayLinkClaim do
  @moduledoc """
  Consumes a single-use (custom) pay link when its order's payment confirms.

  Runs in a transaction with a `FOR UPDATE` lock on the pay_links row — the
  same claim pattern as merchant refunds — so exactly one confirming payment
  wins. A loser (second in-flight payment on a just-consumed link) gets its
  order flagged for merchant refund attention rather than silently
  double-selling. Never raises into the webhook worker.

  Idempotent per order: the winning claim records `claimed_order_id` on the
  link, so a webhook job that retries after a downstream failure (workers
  must be idempotent) recognizes its OWN prior claim and no-ops instead of
  flagging its own legitimate order for a refund it doesn't need.
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  alias Emakola.Repo

  @refund_note "⚠️ Pay link already used — refund this payment."

  # Builds the FOR-UPDATE row lookup used by `claim/2`. Exposed (not private)
  # so `PayLinkClaimTest` can pass it to `Ecto.Adapters.SQL.to_sql/3` and
  # assert the lock clause is present — a deterministic, non-flaky guard
  # against someone dropping `lock: "FOR UPDATE"` (see that test's comment
  # for why a genuine two-connection race test isn't feasible here).
  @doc false
  def locked_row_query(pay_link_id) do
    from(pl in "pay_links",
      where: pl.id == type(^pay_link_id, :binary_id),
      lock: "FOR UPDATE",
      select: %{
        type: pl.type,
        status: pl.status,
        claimed_order_id: type(pl.claimed_order_id, :binary_id)
      }
    )
  end

  def claim_for_order(order_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false)

    case order.pay_link_id do
      nil -> :ok
      pay_link_id -> claim(order, pay_link_id)
    end
  rescue
    e ->
      Logger.error("[pay_link_claim] claim failed for order=#{order_id}: #{inspect(e)}")
      :ok
  end

  defp claim(order, pay_link_id) do
    Repo.transaction(fn ->
      row = Repo.one(locked_row_query(pay_link_id))

      case row do
        %{type: "custom", status: "active"} ->
          link = Ash.get!(Emakola.Orders.PayLink, pay_link_id, authorize?: false)

          link
          |> Ash.Changeset.for_update(:mark_paid, %{claimed_order_id: order.id})
          |> Ash.update!(authorize?: false)

        %{type: "custom", status: "paid", claimed_order_id: claimed_order_id}
        when claimed_order_id == order.id ->
          # This order already won the claim — a webhook retry after a
          # downstream failure, not a race. Idempotent no-op.
          :ok

        %{type: "custom", status: "paid"} ->
          flag_for_refund(order, pay_link_id)

        %{type: "custom", status: "cancelled"} ->
          # The merchant cancelled the link, but the buyer had already
          # reached the gateway's hosted page and paid before the
          # cancellation — that money must never be silently confirmed;
          # flag it for refund attention exactly like an already-claimed
          # link would be.
          flag_for_refund(order, pay_link_id)

        _ ->
          # Catalog links are reusable.
          :ok
      end
    end)

    :ok
  end

  # A losing order's webhook job can itself be retried (workers must be
  # idempotent), which would re-enter this branch every time and append
  # another copy of the note — eventually overflowing `notes`'
  # max_length 5000 and raising, silently swallowed by the outer rescue and
  # dropping the merchant signal entirely. Guard by checking the marker is
  # already present before writing.
  defp flag_for_refund(order, pay_link_id) do
    if String.contains?(order.notes || "", @refund_note) do
      :ok
    else
      Logger.error(
        "[pay_link_claim] link #{pay_link_id} already used — order #{order.id} needs a refund"
      )

      note = String.trim("#{order.notes || ""}\n#{@refund_note}")

      order
      |> Ash.Changeset.for_update(:update_notes, %{notes: note})
      |> Ash.update!(authorize?: false)
    end
  end
end
