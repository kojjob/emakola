defmodule Emakola.ToolingTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  describe "Factory helpers" do
    test "create_user! returns a valid user" do
      user = create_user!()
      assert user.id
      assert user.email
    end

    test "create_organisation! returns an org with slug" do
      org = create_organisation!()
      assert org.id
      assert org.name
      assert org.slug
    end

    test "create_membership! links user and org" do
      user = create_user!()
      org = create_organisation!()
      membership = create_membership!(user, org, :admin)
      assert membership.role == :admin
    end

    test "create_plan! returns a billing plan" do
      plan = create_plan!()
      assert plan.id
      assert plan.stripe_product_id
    end

    test "unique_email returns different emails" do
      emails = for _ <- 1..10, do: unique_email()
      assert length(Enum.uniq(emails)) == 10
    end
  end

  describe "DataCase sandbox" do
    test "database is clean between tests" do
      # This test creates data
      create_user!()
      # Next test should not see this data (sandbox isolation)
    end

    test "async tests are isolated" do
      # Verify we can create resources without conflicts
      for _ <- 1..5, do: create_user!()
    end
  end

  describe "Domain module wiring" do
    test "all domains are configured" do
      domains = Application.get_env(:emakola, :ash_domains)
      assert Emakola.Accounts in domains
      assert Emakola.Billing in domains
      assert Emakola.Notifications in domains
      assert Emakola.Audit in domains
      assert Emakola.FeatureFlags in domains
      assert Emakola.Webhooks in domains
      assert Emakola.Catalog in domains
    end

    test "Repo is configured" do
      repos = Application.get_env(:emakola, :ecto_repos)
      assert Emakola.Repo in repos
    end

    test "Oban queues are configured" do
      oban_config = Application.get_env(:emakola, Oban)
      queues = Keyword.get(oban_config, :queues, [])
      assert Keyword.has_key?(queues, :default)
      assert Keyword.has_key?(queues, :mailers)
      assert Keyword.has_key?(queues, :billing)
    end
  end

  describe "Branding config" do
    test "branding defaults are set" do
      branding = Application.get_env(:emakola, :branding)
      assert branding[:app_name] == "Emakola"
      assert branding[:primary_color] == "#0c1526"
      assert is_binary(branding[:support_email])
    end
  end

  describe "Demo mode" do
    test "demo mode is off by default" do
      refute Emakola.Demo.enabled?()
    end

    test "demo credentials are accessible" do
      assert Emakola.Demo.demo_email() == "demo@emakola.com"
      assert is_binary(Emakola.Demo.demo_password())
    end
  end
end
