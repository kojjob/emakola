defmodule Emakola.Repo.Migrations.AddAttributionToOrders do
  @moduledoc """
  Adds an `attribution` jsonb column to orders so we can persist the
  UTM parameters captured during the customer's session and surface
  them in merchant analytics.

  Shape (set by `EmakolaWeb.Plugs.UtmCapture` -> CheckoutService):

      %{
        "utm_source"   => "instagram",
        "utm_medium"   => "bio_link",
        "utm_campaign" => "spring-2026",
        "utm_content"  => "story-2",
        "utm_term"     => nil,
        "click_to_whatsapp" => false,
        "first_seen_at" => "2026-04-26T10:33:21Z"
      }

  Defaults to an empty map so legacy rows are valid and downstream
  rendering can pattern-match on `%{}` safely.

  Phase 1 of the social media integration plan.
  """
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :attribution, :map, null: false, default: %{}
    end
  end
end
