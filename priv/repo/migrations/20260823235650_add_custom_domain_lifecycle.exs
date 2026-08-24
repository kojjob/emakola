defmodule Emakola.Repo.Migrations.AddCustomDomainLifecycle do
  @moduledoc """
  Custom-domain verification lifecycle on store_domains.

  Two new columns, and both unique indexes become partial:

    * `unique_host` now excludes `:expired` rows, so an abandoned claim stops
      holding a hostname hostage — without this, one merchant claiming
      `nike.com` locks it away from its real owner forever.
    * `one_primary_per_store` is new. `primary?` becomes load-bearing once the
      canonical URL reads it, and nothing stopped two `true` rows before.

  Hand-written rather than taken whole from `mix ash.codegen`: 56 resources in
  this repo have no tracked snapshot, so a full codegen run emits the entire
  schema. Only the store_domains snapshot is updated alongside this.
  """

  use Ecto.Migration

  def up do
    alter table(:store_domains) do
      add :status_reason, :text
      add :verifying_since, :utc_datetime_usec
    end

    drop_if_exists unique_index(:store_domains, [:host], name: "store_domains_unique_host_index")

    create unique_index(:store_domains, [:host],
             name: "store_domains_unique_host_index",
             where: "(status != 'expired')"
           )

    create unique_index(:store_domains, [:store_id],
             name: "store_domains_one_primary_per_store_index",
             where: "(\"primary?\" = TRUE)"
           )
  end

  def down do
    drop_if_exists unique_index(:store_domains, [:store_id],
                     name: "store_domains_one_primary_per_store_index"
                   )

    drop_if_exists unique_index(:store_domains, [:host], name: "store_domains_unique_host_index")

    create unique_index(:store_domains, [:host], name: "store_domains_unique_host_index")

    alter table(:store_domains) do
      remove :verifying_since
      remove :status_reason
    end
  end
end
