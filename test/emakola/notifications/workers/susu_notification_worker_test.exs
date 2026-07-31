defmodule Emakola.Notifications.Workers.SusuNotificationWorkerTest do
  @moduledoc """
  TC-3 Task 8: perform/1 end-to-end tests for the plan-based susu
  notification worker — mirrors `OrderNotificationWorkerTest`'s "test
  through the worker" discipline (SMS body content + signed link +
  channel gating via Mox unexpected-call, not just dispatcher/template
  layer tests).
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.SusuNotificationWorker
  alias Emakola.Orders.SusuPlan
  alias EmakolaWeb.SusuTokens

  setup :verify_on_exit!

  @merchant_phone "+233301234567"

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp activate!(plan, customer) do
    plan
    |> Ash.Changeset.for_update(:activate, %{
      customer_id: customer.id,
      delivery_address: %{"name" => "Ama Mensah", "phone" => "0201234567", "address" => "Accra"}
    })
    |> Ash.update!(authorize?: false)
  end

  defp contribute!(plan, amount) do
    plan
    |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: amount})
    |> Ash.update!(authorize?: false)
  end

  defp store_with_contact! do
    {_merchant, store} = create_merchant_with_store!()

    store
    |> Ash.Changeset.for_update(:update_settings, %{contact_phone: @merchant_phone})
    |> Ash.update!(authorize?: false)
  end

  defp active_plan_with_buyer!(store, buyer_phone \\ "+233201234567") do
    customer = create_customer!(store, %{phone: buyer_phone, name: "Kwame Mensah"})
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    plan = activate!(plan, customer)
    {plan, customer}
  end

  defp perform_job(plan_id, event) do
    SusuNotificationWorker.perform(%Oban.Job{
      args: %{"susu_plan_id" => plan_id, "event" => event}
    })
  end

  defp token_from(message) do
    message |> String.split("?t=") |> List.last() |> String.trim()
  end

  # ── Buyer events ─────────────────────────────────────────────────

  describe "susu_activated event" do
    test "sends the buyer an SMS with progress and a signed susu-plan link — no merchant SMS" do
      store = store_with_contact!()
      {plan, customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "active"
        assert message =~ "?t="

        assert {:ok, plan_id} = SusuTokens.verify_susu_plan(token_from(message))
        assert plan_id == plan.id

        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      # No merchant SMS expectation set — a call here fails via Mox
      # unexpected-call, proving :susu_activated is buyer-only.

      assert :ok == perform_job(plan.id, "susu_activated")
    end
  end

  describe "susu_chunk_received event" do
    test "sends the buyer a progress SMS with a signed link" do
      store = store_with_contact!()
      {plan, customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "Chunk received"
        assert message =~ "?t="
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(plan.id, "susu_chunk_received")
    end
  end

  describe "susu_nudge event" do
    test "sends the buyer a nudge SMS with the remaining balance and a signed link" do
      store = store_with_contact!()
      {plan, customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "week"
        assert message =~ "?t="
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(plan.id, "susu_nudge")
    end
  end

  describe "susu_deadline_warning event" do
    test "sends the buyer a deadline-warning SMS with days interpolated and a signed link" do
      store = store_with_contact!()
      {plan, customer} = active_plan_with_buyer!(store)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "deadline"
        assert message =~ "?t="
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(plan.id, "susu_deadline_warning")
    end
  end

  describe "susu_refunded event" do
    test "sends the buyer a refund-confirmation SMS — no merchant SMS" do
      store = store_with_contact!()
      {plan, customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == customer.phone
        assert message =~ "ended"
        assert message =~ "refunded"
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(plan.id, "susu_refunded")
    end
  end

  # ── Merchant events ───────────────────────────────────────────────

  describe "susu_merchant_activated event" do
    test "sends the merchant an SMS — never the customer channel" do
      store = store_with_contact!()
      {plan, _customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == @merchant_phone
        assert message =~ plan.code
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      # No customer SMS expectation set, even though `customer` has a
      # phone — proves the buyer channel is genuinely skipped.

      assert :ok == perform_job(plan.id, "susu_merchant_activated")
    end
  end

  describe "susu_merchant_expired event" do
    test "sends the merchant an SMS — never the customer channel" do
      store = store_with_contact!()
      {plan, _customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      Emakola.SMSProviderMock
      |> expect(:send_sms, 1, fn to, message, _opts ->
        assert to == @merchant_phone
        assert message =~ plan.code
        {:ok, %{provider: :mock, to: to, message: message}}
      end)

      assert :ok == perform_job(plan.id, "susu_merchant_expired")
    end
  end

  # ── Missing customer / contact ───────────────────────────────────

  describe "no customer on the plan" do
    test "skips the buyer SMS cleanly (pending plan, never activated)" do
      store = store_with_contact!()
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      # No SMS expectation — a call here would fail via Mox.
      assert :ok == perform_job(plan.id, "susu_refunded")
    end
  end

  describe "no store contact_phone" do
    test "skips the merchant SMS cleanly" do
      {_merchant, store} = create_merchant_with_store!()
      {plan, _customer} = active_plan_with_buyer!(store)
      plan = contribute!(plan, 5_000)

      # No SMS expectation — a call here would fail via Mox.
      assert :ok == perform_job(plan.id, "susu_merchant_activated")
    end
  end

  # ── Non-existent plan ─────────────────────────────────────────────

  describe "non-existent plan" do
    test "returns error for unknown susu_plan_id" do
      fake_id = Ash.UUID.generate()
      assert {:error, :plan_not_found} == perform_job(fake_id, "susu_activated")
    end
  end
end
