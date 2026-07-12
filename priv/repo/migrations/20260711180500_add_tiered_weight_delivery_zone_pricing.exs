defmodule Emakola.Repo.Migrations.AddTieredWeightDeliveryZonePricing do
  @moduledoc """
  Adds subtotal-tiered and weight-based pricing columns to delivery zones.

  Both columns are nullable — zones without them behave exactly as before
  (flat per-zone fee), so this ships dark until a merchant opts in.
  """

  use Ecto.Migration

  def change do
    alter table(:delivery_zones) do
      add :free_above_pesewas, :bigint
      add :per_kg_fee_pesewas, :bigint
    end
  end
end
