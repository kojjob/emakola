defmodule Emakola.FeatureFlagsTest do
  use Emakola.DataCase, async: true

  alias Emakola.FeatureFlags
  alias Emakola.FeatureFlags.FeatureFlag

  defp create_flag!(attrs) do
    FeatureFlag
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  describe "FeatureFlag CRUD" do
    test "creates a feature flag" do
      assert {:ok, flag} =
               FeatureFlag
               |> Ash.Changeset.for_create(:create, %{
                 key: "ai_agents",
                 name: "AI Agents",
                 description: "Enable AI agent functionality",
                 enabled: true,
                 required_plan: "starter"
               })
               |> Ash.create(authorize?: false)

      assert flag.key == "ai_agents"
      assert flag.enabled == true
      assert flag.required_plan == "starter"
    end

    test "enforces unique key" do
      create_flag!(%{key: "unique_test", name: "Test"})

      assert {:error, _} =
               FeatureFlag
               |> Ash.Changeset.for_create(:create, %{key: "unique_test", name: "Dupe"})
               |> Ash.create(authorize?: false)
    end

    test "toggles a flag" do
      flag = create_flag!(%{key: "toggle_test", name: "Toggle", enabled: true})

      {:ok, toggled} = flag |> Ash.Changeset.for_update(:toggle) |> Ash.update(authorize?: false)
      assert toggled.enabled == false

      {:ok, toggled_back} =
        toggled |> Ash.Changeset.for_update(:toggle) |> Ash.update(authorize?: false)

      assert toggled_back.enabled == true
    end

    test "requires key and name" do
      assert {:error, _} =
               FeatureFlag
               |> Ash.Changeset.for_create(:create, %{})
               |> Ash.create(authorize?: false)
    end
  end

  describe "enabled?/2 evaluation" do
    test "returns true for enabled flag with no plan requirement" do
      create_flag!(%{key: "global_feature", name: "Global", enabled: true, required_plan: nil})
      assert FeatureFlags.enabled?("global_feature") == true
    end

    test "returns false for disabled flag" do
      create_flag!(%{key: "disabled_feature", name: "Disabled", enabled: false})
      assert FeatureFlags.enabled?("disabled_feature") == false
    end

    test "returns false for non-existent flag" do
      assert FeatureFlags.enabled?("nonexistent") == false
    end

    test "plan gating — starter plan can access starter features" do
      create_flag!(%{
        key: "starter_feature",
        name: "Starter Only",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("starter_feature", plan_slug: "starter") == true
    end

    test "plan gating — free plan cannot access starter features" do
      create_flag!(%{
        key: "paid_feature",
        name: "Paid",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("paid_feature", plan_slug: "free") == false
    end

    test "plan gating — pro plan can access starter features (hierarchy)" do
      create_flag!(%{
        key: "starter_only",
        name: "Starter",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("starter_only", plan_slug: "pro") == true
    end

    test "plan gating — enterprise can access everything" do
      create_flag!(%{
        key: "pro_feature",
        name: "Pro",
        enabled: true,
        required_plan: "pro"
      })

      assert FeatureFlags.enabled?("pro_feature", plan_slug: "enterprise") == true
    end

    test "plan gating — nil plan_slug cannot access plan-gated feature" do
      create_flag!(%{key: "gated", name: "Gated", enabled: true, required_plan: "starter"})
      assert FeatureFlags.enabled?("gated") == false
    end

    test "accepts atom keys" do
      create_flag!(%{key: "atom_test", name: "Atom", enabled: true})
      assert FeatureFlags.enabled?(:atom_test) == true
    end
  end

  describe "edge cases" do
    test "handles unknown plan slug gracefully" do
      create_flag!(%{
        key: "edge_plan",
        name: "Edge",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("edge_plan", plan_slug: "unknown_plan") == false
    end

    test "handles flag with unknown required_plan" do
      create_flag!(%{
        key: "bad_plan",
        name: "Bad",
        enabled: true,
        required_plan: "nonexistent_plan"
      })

      assert FeatureFlags.enabled?("bad_plan", plan_slug: "pro") == false
    end

    test "concurrent flag evaluation" do
      create_flag!(%{key: "concurrent_test", name: "Concurrent", enabled: true})

      tasks =
        for _ <- 1..50 do
          Task.async(fn -> FeatureFlags.enabled?("concurrent_test") end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == true))
    end
  end
end
