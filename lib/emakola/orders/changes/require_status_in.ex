defmodule Emakola.Orders.Changes.RequireStatusIn do
  @moduledoc """
  Constrains a status transition to happen ONLY if the row is still in one of
  the `:from` states at write time.

  `Emakola.Validations.StatusGuard` reads the status off the changeset, which
  for an update is the *in-memory* record the caller loaded. That is fine for
  giving a clear message on the normal path, but it cannot stop a stale caller:
  a merchant with the order open in a second tab (or a back-button page) holds
  a struct that says `:pending` long after the row moved on. The validation
  happily passes and the write lands — a cancelled order could be flipped back
  to `confirmed`, firing the confirmation notification and enqueuing
  fulfilment for an order the customer was told was cancelled.

  Adding the same predicate as a filter pushes it into the UPDATE's WHERE
  clause, so the database decides. If the row no longer matches, zero rows are
  affected and Ash raises `Ash.Error.Changes.StaleRecord` instead of writing.

  Pair it with the validation on every transition action:

      update :confirm do
        validate {StatusGuard, from: [:pending], message: "..."}
        change {RequireStatusIn, from: [:pending]}
        change set_attribute(:status, :confirmed)
      end

  Same pattern as `Emakola.Marketing.Coupon`, which filters on
  `uses_count < max_uses` to stop concurrent over-redemption.
  """
  use Ash.Resource.Change

  require Ash.Expr

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :from) do
      {:ok, from} when is_list(from) and from != [] ->
        {:ok, opts}

      _ ->
        {:error, "RequireStatusIn requires a non-empty :from option"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    from = Keyword.fetch!(opts, :from)
    Ash.Changeset.filter(changeset, Ash.Expr.expr(status in ^from))
  end
end
