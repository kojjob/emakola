defmodule Emakola.Repo.Migrations.AddPhase3SocialFields do
  @moduledoc """
  Phase 3 of social media integration:

    * `reviews.images` — array of image map (`%{url, thumbnail_url, alt}`).
      Defaults to []. Allows customers to attach photos to their reviews,
      which the PDP then renders in a 4-up gallery beneath the review text.
      UGC photos drive 1-5% conversion lift on social-sourced traffic.

    * `products.share_count` — integer counter incremented when a customer
      taps a button on the product's `share_strip` (Phase 1). Displayed on
      the PDP as social proof ("1.2K shares") once the count is > 0.

  Both columns are additive and have safe defaults. Existing reviews keep
  rendering with no photo gallery (the 4-up section is conditional). Existing
  products start at share_count=0 and the PDP hides the badge until > 0.
  """
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      add :images, {:array, :map}, null: false, default: []
    end

    alter table(:products) do
      add :share_count, :integer, null: false, default: 0
    end
  end
end
