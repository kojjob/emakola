defmodule Emakola.Marketing.CampaignSendWorkerTest do
  @moduledoc """
  The send path, where mistakes cost the merchant real money.

  Every SMS is billed, so the properties that matter are: never send twice,
  never send to someone who opted out, and record honestly what happened.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Marketing.{Campaigns, CampaignSendWorker}

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    {merchant, store} = create_merchant_with_store!()

    {:ok, campaign} =
      Campaigns.create(merchant, store.id, %{
        name: "Weekend sale",
        channel: :sms,
        body: "20% off this weekend."
      })

    %{merchant: merchant, store: store, campaign: campaign}
  end

  defp perform(campaign) do
    CampaignSendWorker.perform(%Oban.Job{args: %{"campaign_id" => campaign.id}})
  end

  test "sends to every reachable customer and records the counts", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})
    create_customer!(ctx.store, %{phone: "+233202222222"})

    expect(Emakola.SMSProviderMock, :send_sms, 2, fn _to, body, _opts ->
      assert body == "20% off this weekend."
      {:ok, %{message_id: "sm_1"}}
    end)

    assert :ok = perform(ctx.campaign)

    campaign = Ash.get!(Emakola.Marketing.Campaign, ctx.campaign.id, authorize?: false)
    assert campaign.status == :sent
    assert campaign.sent_count == 2
    assert campaign.failed_count == 0
    assert %DateTime{} = campaign.sent_at
  end

  test "never messages a customer who opted out", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})
    opted_out = create_customer!(ctx.store, %{phone: "+233202222222"})
    {:ok, _} = Campaigns.opt_out(opted_out)

    expect(Emakola.SMSProviderMock, :send_sms, 1, fn to, _body, _opts ->
      assert to == "+233201111111"
      {:ok, %{message_id: "sm_1"}}
    end)

    assert :ok = perform(ctx.campaign)

    campaign = Ash.get!(Emakola.Marketing.Campaign, ctx.campaign.id, authorize?: false)
    assert campaign.sent_count == 1
  end

  test "a rerun does not send the same campaign twice", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})

    # Exactly once across BOTH runs. Oban retries a job whose process died
    # after the provider call succeeded; the claim row is what stops the
    # merchant being charged for a second send.
    expect(Emakola.SMSProviderMock, :send_sms, 1, fn _to, _body, _opts ->
      {:ok, %{message_id: "sm_1"}}
    end)

    assert :ok = perform(ctx.campaign)
    assert :ok = perform(ctx.campaign)
  end

  test "records a failure without failing the whole campaign", ctx do
    create_customer!(ctx.store, %{phone: "+233201111111"})
    create_customer!(ctx.store, %{phone: "+233202222222"})

    expect(Emakola.SMSProviderMock, :send_sms, 2, fn to, _body, _opts ->
      if to == "+233201111111" do
        {:error, :gateway_rejected}
      else
        {:ok, %{message_id: "sm_2"}}
      end
    end)

    assert :ok = perform(ctx.campaign)

    campaign = Ash.get!(Emakola.Marketing.Campaign, ctx.campaign.id, authorize?: false)
    assert campaign.sent_count == 1
    assert campaign.failed_count == 1
    # One bad number must not cost the merchant the rest of the send.
    assert campaign.status == :sent
  end

  test "a campaign with no reachable customers is not left sending forever", ctx do
    assert :ok = perform(ctx.campaign)

    campaign = Ash.get!(Emakola.Marketing.Campaign, ctx.campaign.id, authorize?: false)
    assert campaign.status == :sent
    assert campaign.audience_size == 0
    assert campaign.sent_count == 0
  end
end
