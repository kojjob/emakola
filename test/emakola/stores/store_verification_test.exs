defmodule Emakola.Stores.StoreVerificationTest do
  @moduledoc """
  Per-store business verification + review. Merchants submit a business name and
  an optional supporting document (MMDA licence, tax receipt, incorporation
  certificate) → :pending; platform staff approve/reject (platform-only).

  Identity is NOT established here. L.I. 2523 makes requesting, retaining or
  visually inspecting a Ghana Card an offence, so the national-ID fields are no
  longer accepted. Identity comes from proving control of the payout wallet,
  which the telco has already KYC'd against a Ghana Card.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores

  defp valid_attrs(store) do
    %{
      store_id: store.id,
      business_name: "Ama Trades"
    }
  end

  describe "submit" do
    test "creates a pending submission stamped with submitted_at" do
      store = Factory.create_store!()

      assert {:ok, v} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
      assert v.status == :pending
      assert v.business_name == "Ama Trades"
      assert %DateTime{} = v.submitted_at
    end

    test "succeeds without any national-ID fields" do
      store = Factory.create_store!()

      assert {:ok, v} = Stores.submit_store_verification(valid_attrs(store), authorize?: false)
      assert is_nil(v.id_type)
      assert is_nil(v.id_number)
      assert is_nil(v.id_document_key)
    end

    test "refuses national-ID fields outright — they are unlawful to request" do
      store = Factory.create_store!()

      for field <- [:id_type, :id_number, :id_document_key] do
        attrs = Map.put(valid_attrs(store), field, "GHA-123456789-0")

        assert {:error, _} = Stores.submit_store_verification(attrs, authorize?: false),
               "#{field} must not be accepted by :submit"
      end
    end

    test "accepts an optional supporting business document" do
      store = Factory.create_store!()

      attrs =
        Map.put(valid_attrs(store), :business_doc_key, "verifications/#{store.id}/business-a.pdf")

      assert {:ok, v} = Stores.submit_store_verification(attrs, authorize?: false)
      assert v.business_doc_key =~ "business-"
    end

    test "requires a business name" do
      store = Factory.create_store!()
      attrs = Map.delete(valid_attrs(store), :business_name)
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
               Stores.reject_store_verification(v, %{reason: "Document unreadable"},
                 authorize?: false
               )

      assert rejected.status == :rejected
      assert rejected.review_reason == "Document unreadable"
      assert %DateTime{} = rejected.reviewed_at
    end

    test "resubmit returns a rejected submission to pending and clears the reason", %{
      store: store,
      verification: v
    } do
      {:ok, rejected} = Stores.reject_store_verification(v, %{reason: "x"}, authorize?: false)

      attrs = Map.take(valid_attrs(store), [:business_name])

      assert {:ok, again} = Stores.resubmit_store_verification(rejected, attrs, authorize?: false)
      assert again.status == :pending
      assert is_nil(again.review_reason)
    end

    test "resubmit refuses national-ID fields too", %{verification: v} do
      assert {:error, _} =
               Stores.resubmit_store_verification(v, %{id_number: "GHA-1-0"}, authorize?: false)
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
