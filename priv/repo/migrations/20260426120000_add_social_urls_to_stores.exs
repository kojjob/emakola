defmodule Emakola.Repo.Migrations.AddSocialUrlsToStores do
  @moduledoc """
  Adds social URL columns to stores so merchants can wire their handles
  through to the storefront footer + share buttons.

  All five fields are nullable strings; existing rows get NULL and the
  storefront footer renders zero social icons (same as today). When a
  merchant populates a field via /admin/settings, the corresponding icon
  appears in their theme footer.

  Phase 1 of the social media integration plan.
  """
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :instagram_url, :string
      add :tiktok_url, :string
      add :facebook_url, :string
      add :youtube_url, :string
      add :x_url, :string
    end
  end
end
