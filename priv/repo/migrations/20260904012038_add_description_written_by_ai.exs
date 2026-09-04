defmodule Emakola.Repo.Migrations.AddDescriptionWrittenByAi do
  @moduledoc """
  Marks a product description as AI-written until the merchant changes it.

  Hand-trimmed from `mix ash.codegen` output, which swept in unrelated
  snapshot drift; only the products column belongs to this change.
  """

  use Ecto.Migration

  def up do
    alter table(:products) do
      add :description_written_by_ai, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:products) do
      remove :description_written_by_ai
    end
  end
end
