defmodule Emakola.Repo.Migrations.AddBuyerProtectionToggle do
  @moduledoc """
  TC-2 Buyer Protection opt-in switches: `stores.buyer_protection_enabled`
  (merchant settings toggle, default false, matching `active`'s nullable
  shape) and `pay_links.protected` (per-link override — left nullable with
  no DB default; `PayLink`'s `:create` change always resolves nil to a
  boolean inherited from the store setting, so the column is never actually
  NULL for a row created through the resource).

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (snapshot drift), same as prior single/two-column additions (see
  20260730132507_add_pay_link_claimed_order_id.exs).
  """

  use Ecto.Migration

  def up do
    alter table(:stores) do
      add :buyer_protection_enabled, :boolean, default: false
    end

    alter table(:pay_links) do
      add :protected, :boolean
    end
  end

  def down do
    alter table(:pay_links) do
      remove :protected
    end

    alter table(:stores) do
      remove :buyer_protection_enabled
    end
  end
end
