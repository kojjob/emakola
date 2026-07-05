defmodule Emakola.Repo.Migrations.AddSupplierLogoUrl do
  @moduledoc """
  Adds an optional logo_url to suppliers so merchants can recognise
  suppliers by image instead of text.
  """
  use Ecto.Migration

  def change do
    alter table(:suppliers) do
      add(:logo_url, :text)
    end
  end
end
