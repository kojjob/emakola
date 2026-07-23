defmodule Emakola.Repo.Migrations.AddDispatchFeesToSupplierOffers do
  use Ecto.Migration

  def change do
    # Supplier-quoted dispatch fee per delivery area, integer pesewas.
    # %{"Greater Accra" => 1500}. Empty map = no fees quoted yet.
    alter table(:supplier_offers) do
      add :dispatch_fees, :map, null: false, default: %{}
    end
  end
end
