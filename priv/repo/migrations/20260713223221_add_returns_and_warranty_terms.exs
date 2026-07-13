defmodule Emakola.Repo.Migrations.AddReturnsAndWarrantyTerms do
  use Ecto.Migration

  def change do
    # The merchant's own terms — what the shopper is quoted. Nullable on
    # purpose: no row and no number means the merchant has promised nothing,
    # and the storefront says nothing rather than inventing "30-day returns".
    alter table(:store_page_contents) do
      add :returns_window_days, :integer
      add :warranty_months, :integer
      add :warranty_terms, :text
    end

    # What a supplier will honour back to the reseller. Shown to the merchant,
    # never to the shopper — the merchant is the seller of record.
    alter table(:supplier_offers) do
      add :returns_window_days, :integer
      add :warranty_months, :integer
      add :warranty_terms, :text
    end
  end
end
