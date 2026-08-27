defmodule Emakola.Repo.Migrations.StoreDomainsFkOnDelete do
  @moduledoc """
  Deleting a store used to raise on its domain rows — the FK had no on_delete.
  A domain row is meaningless without its store, so it goes with it.

  Hand-written: mix ash.codegen still emits unrelated resources from
  concurrent branches (see 20260823235650 for the history).
  """

  use Ecto.Migration

  def up do
    drop constraint(:store_domains, "store_domains_store_id_fkey")

    alter table(:store_domains) do
      modify :store_id,
             references(:stores,
               column: :id,
               name: "store_domains_store_id_fkey",
               type: :uuid,
               on_delete: :delete_all
             ),
             null: false
    end
  end

  def down do
    drop constraint(:store_domains, "store_domains_store_id_fkey")

    alter table(:store_domains) do
      modify :store_id,
             references(:stores,
               column: :id,
               name: "store_domains_store_id_fkey",
               type: :uuid
             ),
             null: false
    end
  end
end
