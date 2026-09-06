defmodule Emakola.Repo.Migrations.AddStoreVisitPage do
  @moduledoc """
  Which page a visit landed on, and which product when it was a product page.
  Hand-written. Existing rows were all home-page visits, which is the default.
  """

  use Ecto.Migration

  def up do
    alter table(:store_visits) do
      add :page, :text,
        null: false,
        default: "home"

      add :product_id, :uuid
    end

    create(index(:store_visits, [:store_id, :product_id, :occurred_at]))
  end

  def down do
    drop(index(:store_visits, [:store_id, :product_id, :occurred_at]))

    alter table(:store_visits) do
      remove :product_id
      remove :page
    end
  end
end
