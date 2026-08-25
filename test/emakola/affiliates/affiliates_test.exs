defmodule Emakola.AffiliatesTest do
  @moduledoc """
  Affiliate identity: a phone number, a MoMo number, and a payout container.

  An affiliate is not a merchant and has no shop. But every payout rail in
  this system is keyed to a store — `Payout.store_id` is `allow_nil?: false`
  and `PayoutService.transfer_destination/1` resolves a `StorePayoutAccount`
  by store id. So each affiliate gets one store row that is never a shop,
  purely to hold their MoMo destination, and everything downstream (payable
  reads, refund netting, transfer, reconciliation) works unchanged.

  The risk that buys is leakage: a payout container must never appear
  anywhere a shop appears. That is what `kind` and its guard test are for.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Affiliates
  alias Emakola.Payments.PayoutService

  describe "register/1" do
    test "creates an affiliate with a payout-only store" do
      assert {:ok, affiliate} =
               Affiliates.register(%{
                 phone: "0201234567",
                 name: "Ama Mensah",
                 momo_number: "0201234567",
                 momo_provider: "mtn"
               })

      assert affiliate.name == "Ama Mensah"
      # Stored E.164, whatever the merchant typed.
      assert affiliate.phone == "+233201234567"
      assert is_binary(affiliate.payout_store_id)
    end

    test "the payout store is not a shop" do
      {:ok, affiliate} = Affiliates.register(valid_attrs())

      store = Ash.get!(Emakola.Stores.Store, affiliate.payout_store_id, authorize?: false)

      assert store.kind == :affiliate_payout
    end

    test "the payout destination is usable by the existing transfer path" do
      # The whole reason for the shell store: this function is what pays
      # anybody, and it only knows how to look up a store.
      {:ok, affiliate} = Affiliates.register(valid_attrs())

      assert {:ok, destination} = PayoutService.transfer_destination(affiliate.payout_store_id)
      assert destination.type == "mobile_money"
      assert destination.account_number == "0201234567"
      assert destination.bank_code == "MTN"
    end

    test "the same phone cannot register twice" do
      {:ok, _} = Affiliates.register(valid_attrs())

      assert {:error, _} = Affiliates.register(valid_attrs())
    end

    test "a local and an international spelling of one number are the same person" do
      {:ok, _} = Affiliates.register(valid_attrs(%{phone: "0201234567"}))

      assert {:error, _} = Affiliates.register(valid_attrs(%{phone: "+233201234567"}))
    end

    test "refuses an unknown MoMo provider" do
      # transfer_destination/1 maps provider → bank code; an unmapped provider
      # produces an affiliate who can never be paid.
      assert {:error, _} = Affiliates.register(valid_attrs(%{momo_provider: "barclays"}))
    end
  end

  describe "find_by_phone/1" do
    test "finds however the number is spelled" do
      {:ok, affiliate} = Affiliates.register(valid_attrs())

      assert {:ok, found} = Affiliates.find_by_phone("0201234567")
      assert found.id == affiliate.id

      assert {:ok, same} = Affiliates.find_by_phone("+233201234567")
      assert same.id == affiliate.id
    end

    test "returns an error for a stranger" do
      assert {:error, :not_found} = Affiliates.find_by_phone("+233209999999")
    end
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        phone: "0201234567",
        name: "Ama Mensah",
        momo_number: "0201234567",
        momo_provider: "mtn"
      },
      overrides
    )
  end
end
