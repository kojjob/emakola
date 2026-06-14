defmodule Emakola.FeatureFlagsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.FeatureFlags
  alias Emakola.FeatureFlags.FeatureFlag

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
      Factory.create_feature_flag!(%{key: "unique_test", name: "Test"})

      assert {:error, _} =
               FeatureFlag
               |> Ash.Changeset.for_create(:create, %{key: "unique_test", name: "Dupe"})
               |> Ash.create(authorize?: false)
    end

    test "toggles a flag" do
      flag = Factory.create_feature_flag!(%{key: "toggle_test", name: "Toggle", enabled: true})

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
      Factory.create_feature_flag!(%{
        key: "global_feature",
        name: "Global",
        enabled: true,
        required_plan: nil
      })

      assert FeatureFlags.enabled?("global_feature") == true
    end

    test "returns false for disabled flag" do
      Factory.create_feature_flag!(%{key: "disabled_feature", name: "Disabled", enabled: false})
      assert FeatureFlags.enabled?("disabled_feature") == false
    end

    test "returns false for non-existent flag" do
      assert FeatureFlags.enabled?("nonexistent") == false
    end

    test "plan gating — starter plan can access starter features" do
      Factory.create_feature_flag!(%{
        key: "starter_feature",
        name: "Starter Only",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("starter_feature", plan_slug: "starter") == true
    end

    test "plan gating — free plan cannot access starter features" do
      Factory.create_feature_flag!(%{
        key: "paid_feature",
        name: "Paid",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("paid_feature", plan_slug: "free") == false
    end

    test "plan gating — pro plan can access starter features (hierarchy)" do
      Factory.create_feature_flag!(%{
        key: "starter_only",
        name: "Starter",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("starter_only", plan_slug: "pro") == true
    end

    test "plan gating — enterprise can access everything" do
      Factory.create_feature_flag!(%{
        key: "pro_feature",
        name: "Pro",
        enabled: true,
        required_plan: "pro"
      })

      assert FeatureFlags.enabled?("pro_feature", plan_slug: "enterprise") == true
    end

    test "plan gating — nil plan_slug cannot access plan-gated feature" do
      Factory.create_feature_flag!(%{
        key: "gated",
        name: "Gated",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("gated") == false
    end

    test "accepts atom keys" do
      Factory.create_feature_flag!(%{key: "atom_test", name: "Atom", enabled: true})
      assert FeatureFlags.enabled?(:atom_test) == true
    end
  end

  describe "code interfaces" do
    test "toggle_flag flips enabled" do
      flag = Factory.create_feature_flag!(%{enabled: true})
      assert {:ok, updated} = FeatureFlags.toggle_flag(flag, authorize?: false)
      refute updated.enabled
    end

    test "update_flag changes name and required_plan" do
      flag = Factory.create_feature_flag!(%{name: "Old", required_plan: nil})

      assert {:ok, updated} =
               FeatureFlags.update_flag(flag, %{name: "New", required_plan: "pro"},
                 authorize?: false
               )

      assert updated.name == "New"
      assert updated.required_plan == "pro"
    end

    test "destroy_flag removes the flag" do
      flag = Factory.create_feature_flag!()
      assert :ok = FeatureFlags.destroy_flag(flag, authorize?: false)
      assert {:error, _} = FeatureFlags.get_flag(flag.id, authorize?: false)
    end
  end

  describe "create_platform_admin! factory" do
    test "creates a user flagged as platform admin" do
      admin = Factory.create_platform_admin!()
      assert admin.is_platform_admin == true
    end
  end

  describe "edge cases" do
    test "handles unknown plan slug gracefully" do
      Factory.create_feature_flag!(%{
        key: "edge_plan",
        name: "Edge",
        enabled: true,
        required_plan: "starter"
      })

      assert FeatureFlags.enabled?("edge_plan", plan_slug: "unknown_plan") == false
    end

    test "handles flag with unknown required_plan" do
      Factory.create_feature_flag!(%{
        key: "bad_plan",
        name: "Bad",
        enabled: true,
        required_plan: "nonexistent_plan"
      })

      assert FeatureFlags.enabled?("bad_plan", plan_slug: "pro") == false
    end
  end
end
