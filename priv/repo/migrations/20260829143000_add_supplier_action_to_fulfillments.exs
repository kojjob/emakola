defmodule Emakola.Repo.Migrations.AddSupplierActionToFulfillments do
  @moduledoc """
  Lets a supplier act on a fulfillment themselves, from a link, without a login.

  Four scalar columns, and one asymmetry worth explaining because a future
  reader will ask:

  **Accepting is a timestamp; declining is a status.** `accepted_at` is
  informational — nothing queries or filters on it — and adding an `:accepted`
  status would have meant editing four unrelated consumers that pattern-match
  the status enum. Declining, by contrast, is a blocked order the merchant must
  act on, so it gets `:declined` in `status`. Reusing `:cancelled` for it was
  the obvious shortcut and is a dead end: the merchant's action row is gated on
  `status not in [:delivered, :cancelled]`, so a declined-as-cancelled group
  would lose Cancel and Mark-shipped at exactly the moment the merchant needs
  to re-source the item.

  `supplier_link_version` is the revocation mechanism. The action link is a
  signed `Phoenix.Token` carrying `[fulfillment_id, version]`; bumping this
  column invalidates every token minted before it. That is why there is no
  token table — a merchant who pasted a link into the wrong WhatsApp group
  needs one integer, not a resource with an expiry sweep.

  `null: false, default: 1` applies to existing rows without a table rewrite on
  PostgreSQL 11+. The `:declined` addition to the status enum needs no DDL at
  all: AshPostgres stores atom attributes as plain `text` with no check
  constraint.
  """

  use Ecto.Migration

  def up do
    alter table(:fulfillments) do
      add(:accepted_at, :utc_datetime_usec)
      add(:declined_at, :utc_datetime_usec)
      add(:decline_reason, :text)
      add(:supplier_link_version, :bigint, null: false, default: 1)
    end
  end

  def down do
    alter table(:fulfillments) do
      remove(:accepted_at)
      remove(:declined_at)
      remove(:decline_reason)
      remove(:supplier_link_version)
    end
  end
end
