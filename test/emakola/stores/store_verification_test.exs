defmodule Emakola.Stores.StoreVerificationTest do
  @moduledoc """
  Per-store KYC submission + review. Merchants submit (fields + private doc
  keys) → :pending; platform staff approve/reject (platform-only). Approval is
  the real path to the Store.verified badge (awarded by the LiveView, not here).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores

  defp valid_attrs(store) do
    %{
      store_id: store.id,
      business_name: "Ama Trades",
      id_type: :ghana_card,
      id_number: "GHA-123456789-0",
      id_document_key: "verifications/#{store.id}/id-abc.jpg"
    }
  end

  describe "submit" do
    test "creates a pending submission stamped with submitted_at" do
      store = Factory.create_store!()

      assert {:ok, v} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
      assert v.status == :pending
      assert v.business_name == "Ama Trades"
      assert v.id_type == :ghana_card
      assert v.id_document_key =~ "verifications/"
      assert %DateTime{} = v.submitted_at
    end

    test "requires the id document and core fields" do
      store = Factory.create_store!()
      attrs = Map.delete(valid_attrs(store), :id_document_key)
      assert {:error, _} = Stores.submit_store_verification(attrs, authorize?: false)
    end

    test "one submission per store (unique store_id)" do
      store = Factory.create_store!()
      {:ok, _} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
      assert {:error, _} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
    end
  end

  describe "approve / reject / resubmit" do
    setup do
      store = Factory.create_store!()
      {:ok, v} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
      %{store: store, verification: v}
    end

    test "approve marks approved and stamps reviewed_at", %{verification: v} do
      assert {:ok, approved} = Stores.approve_store_verification(v, %{}, authorize?: false)
      assert approved.status == :approved
      assert %DateTime{} = approved.reviewed_at
    end

    test "reject requires a reason and records it", %{verification: v} do
      assert {:error, _} = Stores.reject_store_verification(v, %{}, authorize?: false)

      assert {:ok, rejected} =
               Stores.reject_store_verification(v, %{reason: "Blurry ID photo"},
                 authorize?: false
               )

      assert rejected.status == :rejected
      assert rejected.review_reason == "Blurry ID photo"
      assert %DateTime{} = rejected.reviewed_at
    end

    test "resubmit returns a rejected submission to pending and clears the reason", %{
      store: store,
      verification: v
    } do
      {:ok, rejected} = Stores.reject_store_verification(v, %{reason: "x"}, authorize?: false)

      attrs =
        Map.take(valid_attrs(store), [:business_name, :id_type, :id_number, :id_document_key])

      assert {:ok, again} = Stores.resubmit_store_verification(rejected, attrs, authorize?: false)
      assert again.status == :pending
      assert is_nil(again.review_reason)
    end
  end

  describe "platform-only review actions" do
    test "a merchant actor cannot approve a submission" do
      {merchant, store} = Factory.create_merchant_with_store!()
      {:ok, v} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)

      assert {:error, _} =
               Stores.approve_store_verification(v, %{}, actor: merchant, authorize?: true)
    end
  end

  describe "reads" do
    test "get_by_store returns the store's submission; list_for_review filters by status" do
      s1 = Factory.create_store!()
      s2 = Factory.create_store!()
      {:ok, _} = Stores.submit_store_verification(valid_attrs(s1), authorize?: false)
      {:ok, v2} = Stores.submit_store_verification(valid_attrs(s2), authorize?: false)
      {:ok, _} = Stores.approve_store_verification(v2, %{}, authorize?: false)

      assert {:ok, %{store_id: id}} = Stores.get_store_verification(s1.id, authorize?: false)
      assert id == s1.id

      assert {:ok, pending} =
               Stores.list_verifications_for_review(%{status: :pending}, authorize?: false)

      assert Enum.map(pending, & &1.store_id) == [s1.id]
    end
  end
end
