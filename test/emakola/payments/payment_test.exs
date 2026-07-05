defmodule Emakola.Payments.PaymentTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Payments.Payment

  import Emakola.Factory

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  describe "create action" do
    test "creates payment with valid attributes", %{store: store} do
      attrs = %{
        store_id: store.id,
        amount: 500_000,
        currency: "GHS",
        gateway: :paystack,
        gateway_reference: "PAY-test-#{System.unique_integer([:positive])}-abc",
        customer_email: "customer@example.com"
      }

      assert {:ok, payment} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert payment.store_id == store.id
      assert payment.amount == 500_000
      assert payment.currency == "GHS"
      assert payment.status == :pending
      assert payment.gateway == :paystack
      assert payment.refunded_amount == 0
      assert payment.metadata == %{}
    end

    test "requires store_id", %{store: _store} do
      attrs = %{
        amount: 500_000,
        currency: "GHS",
        gateway: :paystack,
        gateway_reference: "PAY-test-ref"
      }

      assert {:error, _changeset} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end

    test "requires amount", %{store: store} do
      attrs = %{
        store_id: store.id,
        currency: "GHS",
        gateway: :paystack,
        gateway_reference: "PAY-test-ref"
      }

      assert {:error, _changeset} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end

    test "requires gateway", %{store: store} do
      attrs = %{
        store_id: store.id,
        amount: 500_000,
        currency: "GHS",
        gateway_reference: "PAY-test-ref"
      }

      assert {:error, _changeset} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end

    test "defaults currency to GHS", %{store: store} do
      attrs = %{
        store_id: store.id,
        amount: 500_000,
        gateway: :paystack,
        gateway_reference: "PAY-default-currency-#{System.unique_integer([:positive])}"
      }

      assert {:ok, payment} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert payment.currency == "GHS"
    end

    test "stores optional metadata", %{store: store} do
      metadata = %{"order_id" => "order-123", "channel" => "web"}

      attrs = %{
        store_id: store.id,
        amount: 500_000,
        gateway: :paystack,
        gateway_reference: "PAY-meta-#{System.unique_integer([:positive])}",
        metadata: metadata
      }

      assert {:ok, payment} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert payment.metadata == metadata
    end
  end

  describe "gateway_reference uniqueness" do
    test "prevents duplicate gateway references", %{store: store} do
      reference = "PAY-unique-#{System.unique_integer([:positive])}"

      attrs = %{
        store_id: store.id,
        amount: 500_000,
        gateway: :paystack,
        gateway_reference: reference
      }

      assert {:ok, _payment} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert {:error, _changeset} =
               Payment
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end
  end

  describe "status transitions" do
    setup %{store: store} do
      reference = "PAY-status-#{System.unique_integer([:positive])}"

      {:ok, payment} =
        Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          amount: 500_000,
          gateway: :paystack,
          gateway_reference: reference
        })
        |> Ash.create(authorize?: false)

      %{payment: payment}
    end

    test "mark_success transitions pending to success", %{payment: payment} do
      assert payment.status == :pending

      assert {:ok, updated} =
               payment
               |> Ash.Changeset.for_update(:mark_success, %{
                 gateway_response: %{"gateway_response" => "Successful"}
               })
               |> Ash.update(authorize?: false)

      assert updated.status == :success
      assert updated.gateway_response["gateway_response"] == "Successful"
    end

    test "mark_failed transitions pending to failed", %{payment: payment} do
      assert payment.status == :pending

      assert {:ok, updated} =
               payment
               |> Ash.Changeset.for_update(:mark_failed, %{
                 gateway_response: %{"gateway_response" => "Declined"}
               })
               |> Ash.update(authorize?: false)

      assert updated.status == :failed
      assert updated.gateway_response["gateway_response"] == "Declined"
    end

    test "mark_refunded transitions to refunded with full amount", %{payment: payment} do
      # First mark as success
      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      # Full refund (payment amount is 500_000) flips the status to :refunded.
      assert {:ok, updated} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
               |> Ash.update(authorize?: false)

      assert updated.status == :refunded
      assert updated.refunded_amount == 500_000
    end
  end

  describe "read actions" do
    test "get_by_reference finds payment by gateway_reference", %{store: store} do
      reference = "PAY-read-#{System.unique_integer([:positive])}"

      {:ok, created} =
        Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          amount: 500_000,
          gateway: :paystack,
          gateway_reference: reference
        })
        |> Ash.create(authorize?: false)

      assert {:ok, found} =
               Payment
               |> Ash.Query.filter(gateway_reference == ^reference)
               |> Ash.read_one(authorize?: false)

      assert found.id == created.id
    end
  end
end
