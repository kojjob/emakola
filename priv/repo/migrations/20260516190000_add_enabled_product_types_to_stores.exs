defmodule Emakola.Repo.Migrations.AddEnabledProductTypesToStores do
  @moduledoc """
  Adds `enabled_product_types` to stores — the set of product types the
  merchant has opted into selling. Drives the merchant admin's "new
  product" type picker and gates which `Emakola.Fulfillment.Dispatcher`
  paths the store can actually invoke.

  Existing stores backfill to `{physical}` so behavior is unchanged on
  the day Phase 0 ships.
  """
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :enabled_product_types, {:array, :string}, null: false, default: ["physical"]
    end
  end
end
