defmodule Emakola.Repo.Migrations.AddGhanaDigitalAddressAndLandmark do
  @moduledoc """
  TC-4 GhanaPost addressing: adds optional `digital_address` (GhanaPost GPS
  code, e.g. `GA-183-8164`) and `landmark` (free-text delivery hint) string
  columns to `addresses` (customer saved addresses) and `stores` (merchant
  profile address).

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (pre-existing snapshot drift on unrelated resources), same as prior
  single/two-column additions (see
  20260730160000_add_buyer_protection_toggle.exs).
  """

  use Ecto.Migration

  def up do
    alter table(:addresses) do
      add :digital_address, :text
      add :landmark, :text
    end

    alter table(:stores) do
      add :digital_address, :text
      add :landmark, :text
    end
  end

  def down do
    alter table(:stores) do
      remove :landmark
      remove :digital_address
    end

    alter table(:addresses) do
      remove :landmark
      remove :digital_address
    end
  end
end
