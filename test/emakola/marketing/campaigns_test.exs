defmodule Emakola.Marketing.CampaignsTest do
  @moduledoc """
  The campaign engine's contract.

  Two things this deliberately does NOT do, both learned from the page it
  replaces: it never reports opens or clicks (neither channel reports them
  without provider webhooks), and it never sends to a customer who opted out
  — every SMS costs the merchant money.
  """
  use Emakola.DataCase, async: false

  alias Emakola.Marketing.Campaigns

  import Emakola.Factory

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  describe "create/3" do
    test "creates a draft campaign for the store", %{merchant: merchant, store: store} do
      assert {:ok, campaign} =
               Campaigns.create(merchant, store.id, %{
                 name: "Weekend sale",
                 channel: :sms,
                 body: "Kente Kingdom: 20% off this weekend only."
               })

      assert campaign.name == "Weekend sale"
      assert campaign.channel == :sms
      assert campaign.status == :draft
      assert campaign.store_id == store.id
      assert campaign.sent_count == 0
      assert campaign.failed_count == 0
    end

    test "rejects an empty message", %{merchant: merchant, store: store} do
      assert {:error, _} =
               Campaigns.create(merchant, store.id, %{
                 name: "Empty",
                 channel: :sms,
                 body: ""
               })
    end

    test "rejects a body over one SMS segment budget", %{merchant: merchant, store: store} do
      # 480 chars is >3 SMS segments; the merchant pays per segment, so the
      # limit is a cost guard, not a formatting preference.
      assert {:error, _} =
               Campaigns.create(merchant, store.id, %{
                 name: "Too long",
                 channel: :sms,
                 body: String.duplicate("a", 481)
               })
    end
  end

  describe "audience/2" do
    test "counts customers with a phone number", %{merchant: merchant, store: store} do
      create_customer!(store, %{phone: "+233201111111"})
      create_customer!(store, %{phone: "+233202222222"})
      create_customer!(store, %{phone: nil})

      assert {:ok, %{count: 2}} = Campaigns.audience(merchant, store.id)
    end

    test "excludes customers who opted out", %{merchant: merchant, store: store} do
      create_customer!(store, %{phone: "+233201111111"})
      opted_out = create_customer!(store, %{phone: "+233202222222"})

      {:ok, _} = Campaigns.opt_out(opted_out)

      assert {:ok, %{count: 1}} = Campaigns.audience(merchant, store.id)
    end

    test "never counts another store's customers", %{merchant: merchant, store: store} do
      {_other_merchant, other_store} = create_merchant_with_store!()
      create_customer!(store, %{phone: "+233201111111"})
      create_customer!(other_store, %{phone: "+233209999999"})

      assert {:ok, %{count: 1}} = Campaigns.audience(merchant, store.id)
    end
  end

  describe "list/2" do
    test "returns the store's campaigns, newest first", %{merchant: merchant, store: store} do
      {:ok, _first} =
        Campaigns.create(merchant, store.id, %{name: "One", channel: :sms, body: "hello"})

      {:ok, second} =
        Campaigns.create(merchant, store.id, %{name: "Two", channel: :sms, body: "hello"})

      assert {:ok, [newest | _]} = Campaigns.list(merchant, store.id)
      assert newest.id == second.id
    end

    test "never returns another store's campaigns", %{merchant: merchant, store: store} do
      {other_merchant, other_store} = create_merchant_with_store!()

      {:ok, _theirs} =
        Campaigns.create(other_merchant, other_store.id, %{
          name: "Theirs",
          channel: :sms,
          body: "hello"
        })

      assert {:ok, []} = Campaigns.list(merchant, store.id)
    end
  end

  describe "get_for_store/2" do
    test "returns the campaign when it belongs to the store", %{merchant: merchant, store: store} do
      {:ok, campaign} =
        Campaigns.create(merchant, store.id, %{name: "One", channel: :sms, body: "hello"})

      assert {:ok, found} = Campaigns.get_for_store(store.id, campaign.id)
      assert found.id == campaign.id
    end

    test "not found for another store's campaign", %{merchant: _merchant, store: store} do
      {other_merchant, other_store} = create_merchant_with_store!()

      {:ok, theirs} =
        Campaigns.create(other_merchant, other_store.id, %{
          name: "Theirs",
          channel: :sms,
          body: "hello"
        })

      assert {:error, :not_found} = Campaigns.get_for_store(store.id, theirs.id)
    end

    test "not found for a non-UUID id, rather than raising", %{store: store} do
      assert {:error, :not_found} = Campaigns.get_for_store(store.id, "abc")
    end
  end

  describe "failed_recipients/2" do
    test "caps at 50 rows even when more failed", %{merchant: merchant, store: store} do
      {:ok, campaign} =
        Campaigns.create(merchant, store.id, %{name: "Sale", channel: :sms, body: "Sale on."})

      for i <- 1..60 do
        customer =
          create_customer!(store, %{phone: "+23320000#{String.pad_leading("#{i}", 4, "0")}"})

        {:ok, recipient} =
          Emakola.Marketing.CampaignRecipient
          |> Ash.Changeset.for_create(:claim, %{
            campaign_id: campaign.id,
            customer_id: customer.id,
            phone: customer.phone
          })
          |> Ash.create(authorize?: false)

        recipient
        |> Ash.Changeset.for_update(:mark_failed, %{error: "boom"})
        |> Ash.update!(authorize?: false)
      end

      assert {:ok, recipients} = Campaigns.failed_recipients(store.id, campaign.id)
      assert length(recipients) == 50
    end

    test "not found for another store's campaign", %{store: store} do
      {other_merchant, other_store} = create_merchant_with_store!()

      {:ok, theirs} =
        Campaigns.create(other_merchant, other_store.id, %{
          name: "Theirs",
          channel: :sms,
          body: "hello"
        })

      assert {:error, :not_found} = Campaigns.failed_recipients(store.id, theirs.id)
    end
  end

  describe "mark_sending/2" do
    test "moves a draft to sending with the given audience size", %{
      merchant: merchant,
      store: store
    } do
      {:ok, campaign} =
        Campaigns.create(merchant, store.id, %{name: "One", channel: :sms, body: "hello"})

      assert {:ok, sending} = Campaigns.mark_sending(campaign, 3)
      assert sending.status == :sending
      assert sending.audience_size == 3
    end

    test "sending is allowed to re-enter itself (the worker marks it again)", %{
      merchant: merchant,
      store: store
    } do
      {:ok, campaign} =
        Campaigns.create(merchant, store.id, %{name: "One", channel: :sms, body: "hello"})

      {:ok, sending} = Campaigns.mark_sending(campaign, 3)

      assert {:ok, sending_again} = Campaigns.mark_sending(sending, 5)
      assert sending_again.status == :sending
      assert sending_again.audience_size == 5
    end

    test "refuses to re-send an already-sent campaign", %{merchant: merchant, store: store} do
      {:ok, campaign} =
        Campaigns.create(merchant, store.id, %{name: "One", channel: :sms, body: "hello"})

      {:ok, sending} = Campaigns.mark_sending(campaign, 0)

      {:ok, sent} =
        sending
        |> Ash.Changeset.for_update(:record_result, %{sent_count: 0, failed_count: 0})
        |> Ash.update(authorize?: false)

      assert {:error, _} = Campaigns.mark_sending(sent, 1)
    end
  end
end
