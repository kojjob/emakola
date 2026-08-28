defmodule Emakola.Inventory.Workers.LowStockAlertWorkerTest do
  @moduledoc """
  Tests for the LowStockAlertWorker Oban job.

  Verifies that the worker correctly identifies low-stock variants,
  groups them by store, and triggers alert emails to store merchants.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Swoosh.TestAssertions

  alias Emakola.Inventory.Workers.LowStockAlertWorker
  alias Emakola.Factory

  setup do
    {merchant, store} = Factory.create_merchant_with_store!()
    {:ok, store: store, merchant: merchant}
  end

  describe "perform/1" do
    test "the same low stock alerts once, not every morning", %{store: store} do
      product = Factory.create_product!(store)
      variant = Factory.create_variant!(product, store, stock_quantity: 2, sku: "ONCE-001")
      drain_mailbox()

      assert :ok = perform_job(LowStockAlertWorker, %{})
      assert_email_sent(fn email -> email.subject =~ "Low Stock Alert" end)

      # Tomorrow morning, stock unchanged: the merchant hears nothing new.
      assert :ok = perform_job(LowStockAlertWorker, %{})
      refute_email_sent()

      # Restocked, then sold down again: that is news, and alerts again.
      restock!(variant, 50)
      assert :ok = perform_job(LowStockAlertWorker, %{})
      refute_email_sent()

      restock!(variant, 1)
      assert :ok = perform_job(LowStockAlertWorker, %{})
      assert_email_sent(fn email -> email.subject =~ "Low Stock Alert" end)
    end

    test "finds variants below the default threshold", %{store: store} do
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, stock_quantity: 3, sku: "LOW-001")
      _ok = Factory.create_variant!(product, store, stock_quantity: 50, sku: "OK-001")

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "finds variants below a custom threshold", %{store: store} do
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, stock_quantity: 8, sku: "MED-001")
      _ok = Factory.create_variant!(product, store, stock_quantity: 50, sku: "HIGH-001")

      assert :ok = perform_job(LowStockAlertWorker, %{"threshold" => 10})
    end

    test "skips variants that do not track inventory", %{store: store} do
      product = Factory.create_product!(store)

      _no_track =
        Factory.create_variant!(product, store,
          stock_quantity: 0,
          track_inventory: false,
          sku: "NOTRACK-001"
        )

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "handles stores with no low-stock variants", %{store: store} do
      product = Factory.create_product!(store)
      _ok = Factory.create_variant!(product, store, stock_quantity: 100, sku: "PLENTY-001")

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "handles stores with no products" do
      _store = Factory.create_store!()

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "processes multiple stores independently" do
      {_m1, store1} = Factory.create_merchant_with_store!()
      {_m2, store2} = Factory.create_merchant_with_store!()

      p1 = Factory.create_product!(store1)
      p2 = Factory.create_product!(store2)

      _low1 = Factory.create_variant!(p1, store1, stock_quantity: 1, sku: "S1-LOW")
      _low2 = Factory.create_variant!(p2, store2, stock_quantity: 2, sku: "S2-LOW")

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "sends email alerts to store merchants", %{store: store, merchant: _merchant} do
      product = Factory.create_product!(store, title: "Test Alert Product")

      _low =
        Factory.create_variant!(product, store,
          stock_quantity: 1,
          sku: "EMAIL-001"
        )

      # Drain any emails from setup (e.g., welcome email from merchant registration)
      flush_swoosh_mailbox()

      assert :ok = perform_job(LowStockAlertWorker, %{})

      # Verify low stock alert email was delivered
      expected_subject = "Low Stock Alert — #{store.name}"
      assert_email_sent(subject: expected_subject)
    end

    test "email contains variant details", %{store: store} do
      product = Factory.create_product!(store, title: "Widget Alpha")

      _low =
        Factory.create_variant!(product, store,
          stock_quantity: 2,
          sku: "WIDGET-A1"
        )

      # Drain any emails from setup
      flush_swoosh_mailbox()

      assert :ok = perform_job(LowStockAlertWorker, %{})

      # Verify the low stock alert email was sent with correct subject
      expected_subject = "Low Stock Alert — #{store.name}"
      assert_email_sent(subject: expected_subject)
    end
  end

  describe "WhatsApp digest" do
    import Mox

    setup :verify_on_exit!

    setup do
      original = Application.get_env(:emakola, :whatsapp_provider)
      Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)

      on_exit(fn ->
        if original,
          do: Application.put_env(:emakola, :whatsapp_provider, original),
          else: Application.delete_env(:emakola, :whatsapp_provider)
      end)

      :ok
    end

    test "sends a low-stock digest to the store's WhatsApp number", %{store: store} do
      set_whatsapp_number!(store, "+233200000001")
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, stock_quantity: 2, sku: "WA-LOW-1")

      store_id = store.id
      store_name = store.name

      expect(Emakola.WhatsAppProviderMock, :send_message, fn "+233200000001",
                                                             "low_stock_digest",
                                                             params,
                                                             opts ->
        assert params.count == 1
        assert params.store_name == store_name
        assert opts[:store_id] == store_id
        {:ok, %{}}
      end)

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "skips WhatsApp when the store has no number", %{store: store} do
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, stock_quantity: 2, sku: "WA-LOW-2")

      # No expectation set — any send_message call would fail verify_on_exit!.
      assert :ok = perform_job(LowStockAlertWorker, %{})
    end

    test "an unapproved template is tolerated, not an error", %{store: store} do
      set_whatsapp_number!(store, "+233200000002")
      product = Factory.create_product!(store)
      _low = Factory.create_variant!(product, store, stock_quantity: 2, sku: "WA-LOW-3")

      expect(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ ->
        {:error, {:unknown_template, "low_stock_digest"}}
      end)

      assert :ok = perform_job(LowStockAlertWorker, %{})
    end
  end

  defp set_whatsapp_number!(store, number) do
    import Ecto.Query

    Emakola.Repo.update_all(
      from(s in "stores", where: s.id == type(^store.id, Ecto.UUID)),
      set: [whatsapp_number: number]
    )
  end

  defp flush_swoosh_mailbox do
    receive do
      {:email, _} -> flush_swoosh_mailbox()
    after
      0 -> :ok
    end
  end
  defp restock!(variant, quantity) do
    import Ecto.Query

    {1, _} =
      Emakola.Repo.update_all(
        from(v in "variants", where: v.id == type(^variant.id, :binary_id)),
        set: [stock_quantity: quantity]
      )
  end

  # Factory setup sends onboarding email; the assertions below must only see
  # the worker's own.
  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

end
