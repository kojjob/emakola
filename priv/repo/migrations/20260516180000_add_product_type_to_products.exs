defmodule Emakola.Repo.Migrations.AddProductTypeToProducts do
  @moduledoc """
  Adds the `product_type` enum column to products. Distinguishes physical
  goods from digital downloads, license keys, streaming, course, auction,
  and print-on-demand products. Each type drives a different fulfillment
  path through `Emakola.Fulfillment.Dispatcher`.

  Stored as text and constrained at the Ash layer (`one_of` constraint
  on the resource). All existing rows default to "physical".
  """
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :product_type, :string, null: false, default: "physical"
    end

    create index(:products, [:store_id, :product_type])
  end
end
