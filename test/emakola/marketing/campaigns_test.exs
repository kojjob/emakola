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
end
