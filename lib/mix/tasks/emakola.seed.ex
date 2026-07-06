defmodule Mix.Tasks.Emakola.Seed do
  @moduledoc """
  Seeds the database with sample data for development.

      mix emakola.seed
  """
  use Mix.Task

  @shortdoc "Seed development data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("🌱 Seeding Emakola development data...")

    # Seed plans first
    Mix.Task.run("emakola.seed_plans")

    # Seed demo user and org
    seed_demo_data()

    # Seed feature flags
    seed_feature_flags()

    Mix.shell().info("✅ Seeding complete!")
  end

  defp seed_demo_data do
    alias Emakola.Accounts.{User, Organisation, Membership}

    # Create demo user
    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "demo@emakola.com",
        password: "DemoPassword123!",
        password_confirmation: "DemoPassword123!"
      })
      |> Ash.create()

    # Set the user's full name
    user
    |> Ash.Changeset.for_update(:update_profile, %{name: "Demo User"})
    |> Ash.update!()

    Mix.shell().info("  Created demo user: Demo User (demo@emakola.com)")

    # Create demo org
    {:ok, org} =
      Organisation
      |> Ash.Changeset.for_create(:create, %{name: "Emakola Demo"})
      |> Ash.create()

    Mix.shell().info("  Created demo org: Emakola Demo")

    # Link user as owner
    Membership
    |> Ash.Changeset.for_create(:create, %{
      role: :owner,
      user_id: user.id,
      organisation_id: org.id
    })
    |> Ash.create!()

    Mix.shell().info("  Linked user as org owner")

    # Create a sample agent
    Emakola.AI.Agent
    |> Ash.Changeset.for_create(:create, %{
      name: "Research Assistant",
      description: "A helpful research assistant powered by Claude.",
      system_prompt:
        "You are a knowledgeable research assistant. Help users find information, summarize documents, and answer questions accurately.",
      model: "claude-sonnet-4-20250514",
      provider: :anthropic,
      organisation_id: org.id
    })
    |> Ash.create!()

    Mix.shell().info("  Created sample agent: Research Assistant")
  rescue
    e ->
      Mix.shell().info("  ⚠ Demo data may already exist: #{Exception.message(e)}")
  end

  defp seed_feature_flags do
    alias Emakola.FeatureFlags.FeatureFlag

    flags = [
      %{key: "ai_agents", name: "AI Agents", enabled: true, required_plan: "starter"},
      %{key: "custom_branding", name: "Custom Branding", enabled: true, required_plan: "pro"},
      %{key: "sso", name: "Single Sign-On", enabled: true, required_plan: "enterprise"},
      %{key: "api_access", name: "API Access", enabled: true, required_plan: "starter"},
      %{key: "webhooks", name: "Outbound Webhooks", enabled: true, required_plan: "pro"},
      %{key: "audit_log", name: "Audit Log", enabled: true, required_plan: "pro"},
      %{
        key: "priority_support",
        name: "Priority Support",
        enabled: true,
        required_plan: "starter"
      }
    ]

    require Ash.Query

    Enum.each(flags, fn flag_attrs ->
      key = flag_attrs.key

      case FeatureFlag
           |> Ash.Query.filter(key: key)
           |> Ash.read_one() do
        {:ok, nil} ->
          FeatureFlag
          |> Ash.Changeset.for_create(:create, flag_attrs)
          |> Ash.create!()

          Mix.shell().info("  Created flag: #{flag_attrs.name}")

        {:ok, _} ->
          Mix.shell().info("  Flag exists: #{flag_attrs.name}")
      end
    end)
  end
end
