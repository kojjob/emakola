defmodule Emakola.Notifications.ReachTest do
  @moduledoc """
  Which channels will actually reach a person.

  The rule this encodes: **never assume email**. Most Makola merchants and
  buyers do not use it, and a notification sent only by email is, for them,
  a notification that was never sent.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Marketing.Campaigns
  alias Emakola.Notifications.Reach

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  describe "channels_for/2 — transactional" do
    test "prefers WhatsApp, then SMS, then email", %{store: store} do
      customer = create_customer!(store, %{phone: "+233201111111", email: "buyer@example.com"})

      assert Reach.channels_for(customer, :transactional) == [:whatsapp, :sms, :email]
    end

    test "a person with only a phone is still reachable" do
      # Built as a map, not a row: Customer.email is still allow_nil?(false)
      # (plan step A0), which is precisely the gap this resolver exists for.
      assert Reach.channels_for(%{phone: "+233201111111", email: nil}, :transactional) ==
               [:whatsapp, :sms]
    end

    test "a customer with only an email is reachable by email alone", %{store: store} do
      customer = create_customer!(store, %{phone: nil, email: "buyer@example.com"})

      assert Reach.channels_for(customer, :transactional) == [:email]
    end

    test "an email-less, phone-less person is reachable by nothing" do
      assert Reach.channels_for(%{phone: nil, email: nil}, :transactional) == []
    end

    test "a blank phone counts as no phone" do
      assert Reach.channels_for(%{phone: "   ", email: nil}, :transactional) == []
    end
  end

  describe "channels_for/2 — marketing" do
    test "an opted-out customer is reachable by nothing, whatever they have", %{store: store} do
      customer = create_customer!(store, %{phone: "+233201111111", email: "buyer@example.com"})
      {:ok, customer} = Campaigns.opt_out(customer)

      assert Reach.channels_for(customer, :marketing) == []
    end

    test "an opt-out never suppresses transactional messages", %{store: store} do
      # Opting out of marketing must not stop a customer being told their
      # order shipped — that is information they asked for by buying.
      customer = create_customer!(store, %{phone: "+233201111111"})
      {:ok, customer} = Campaigns.opt_out(customer)

      assert Reach.channels_for(customer, :transactional) == [:whatsapp, :sms, :email]
    end
  end

  describe "reachable?/2" do
    test "is false when nothing will reach them" do
      refute Reach.reachable?(%{phone: nil, email: nil}, :transactional)
    end

    test "is true when any channel will", %{store: store} do
      assert Reach.reachable?(create_customer!(store, %{phone: "+233201111111"}), :transactional)
    end
  end

  describe "merchants" do
    test "a merchant with a phone is reachable on it" do
      merchant = create_merchant!(%{phone: "+233209999999"})

      assert :sms in Reach.channels_for(merchant, :transactional)
    end
  end
end
