defmodule Emakola.Repo.Migrations.AddCampaignAudience do
  @moduledoc """
  Which segment a campaign is for. Hand-written; existing campaigns were all
  sent to everyone, which is the default.
  """

  use Ecto.Migration

  def up do
    alter table(:campaigns) do
      add :audience, :text,
        null: false,
        default: "everyone"
    end
  end

  def down do
    alter table(:campaigns) do
      remove :audience
    end
  end
end
