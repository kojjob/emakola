defmodule Emakola.Repo.Migrations.AddPayLinkClaimedOrderId do
  @moduledoc """
  Adds `pay_links.claimed_order_id`, set by
  `Emakola.Orders.PayLinkClaim.claim_for_order/1` when a custom link's
  webhook-confirming payment claims it. Lets the claim tell apart an
  idempotent retry of the SAME winning order's webhook job (id matches, no
  refund note) from a genuine second order racing an already-consumed link
  (id differs, flag for refund attention) — see the worker-idempotency
  requirement in CLAUDE.md.

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (snapshot drift; it also currently crashes on an unrelated
  `:unique_payment` identity while snapshotting the whole app), same as
  prior single-column additions in this repo (see
  20260716094500_add_confirmed_at_for_hijack_guard.exs).
  """

  use Ecto.Migration

  def up do
    alter table(:pay_links) do
      add :claimed_order_id, :uuid
    end
  end

  def down do
    alter table(:pay_links) do
      remove :claimed_order_id
    end
  end
end
