defmodule Emakola.BillingTest do
  use Emakola.DataCase, async: true

  alias Emakola.Billing.{Plan, Subscription, UsageRecord}
  import Emakola.Factory

  describe "Plan" do
    test "creates a plan" do
      assert {:ok, plan} =
               Plan
               |> Ash.Changeset.for_create(:create, %{
                 name: "Test Plan",
                 slug: "test-plan-#{System.unique_integer([:positive])}",
                 stripe_product_id: "prod_test_#{System.unique_integer([:positive])}",
                 stripe_price_id: "price_test_#{System.unique_integer([:positive])}",
                 price_cents: 2900,
                 interval: :monthly,
                 features: ["Feature A", "Feature B"],
                 max_seats: 5,
                 max_agents: 10,
                 max_api_calls_per_month: 10_000
               })
               |> Ash.create()

      assert plan.name == "Test Plan"
      assert plan.price_cents == 2900
    end
  end

  describe "Subscription" do
    test "creates a subscription for an org" do
      org = create_organisation!()
      plan = create_plan!()

      assert {:ok, sub} =
               Subscription
               |> Ash.Changeset.for_create(:create, %{
                 stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
                 stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
                 status: :active,
                 organisation_id: org.id,
                 plan_id: plan.id
               })
               |> Ash.create()

      assert sub.status == :active
    end

    test "cancels a subscription" do
      org = create_organisation!()
      plan = create_plan!()

      {:ok, sub} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: "sub_cancel_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_cancel_#{System.unique_integer([:positive])}",
          status: :active,
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      assert {:ok, canceled} =
               sub
               |> Ash.Changeset.for_update(:cancel)
               |> Ash.update()

      assert canceled.status == :canceled
      assert canceled.canceled_at
    end
  end

  describe "UsageRecord" do
    test "records usage for an org" do
      org = create_organisation!()

      assert {:ok, record} =
               UsageRecord
               |> Ash.Changeset.for_create(:create, %{
                 event_type: "agent.run",
                 quantity: 1,
                 metadata: %{"agent_id" => "test"},
                 organisation_id: org.id
               })
               |> Ash.create()

      assert record.event_type == "agent.run"
      assert record.quantity == 1
    end
  end

  describe "StripeHandler worker" do
    test "handles unknown event type gracefully" do
      assert :ok =
               Emakola.Billing.Workers.StripeHandler.perform(%Oban.Job{
                 args: %{"type" => "unknown.event", "data" => %{}}
               })
    end
  end
end
