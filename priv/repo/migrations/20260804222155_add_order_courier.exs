defmodule Emakola.Repo.Migrations.AddOrderCourier do
  @moduledoc """
  Which courier an order's `tracking_number` belongs to, so a buyer gets a link
  rather than a reference they must guess where to type.

  Hand-written because `mix ash.codegen` cannot run in this repo at present: it
  aborts on a PRE-EXISTING config gap unrelated to this change —

      Must provide an entry for :unique_payment in
      `postgres.identity_wheres_to_sql`, or skip this identity with
      `postgres.skip_unique_indexes`.

  Ash stores a plain `:atom` attribute as text (see `notified_via` on
  fulfillments), so this matches what codegen would have produced. Worth fixing
  the Payment identity config separately — until then no migration can be
  generated at all.
  """
  use Ecto.Migration

  def up do
    alter table(:orders) do
      add :courier, :text
    end
  end

  def down do
    alter table(:orders) do
      remove :courier
    end
  end
end
