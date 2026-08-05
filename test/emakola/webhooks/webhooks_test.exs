defmodule Emakola.WebhooksTest do
  use Emakola.DataCase, async: true

  alias Emakola.Webhooks.{OutboundWebhook, WebhookDelivery}
  alias Emakola.Webhooks.Workers.WebhookDeliveryWorker
  import Emakola.Factory

  describe "OutboundWebhook CRUD" do
    test "creates a webhook" do
      org = create_organisation!()

      assert {:ok, wh} =
               OutboundWebhook
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://example.com/webhook",
                 secret: "whsec_test_secret_123",
                 events: ["agent.completed", "billing.updated"],
                 organisation_id: org.id
               })
               |> Ash.create(authorize?: false)

      assert wh.url == "https://example.com/webhook"
      assert wh.active == true
      assert length(wh.events) == 2
      assert Emakola.Security.FieldEncryption.encrypted?(wh.secret_encrypted)

      assert {:ok, "whsec_test_secret_123"} =
               Emakola.Security.SecretStorage.outbound_webhook_secret(wh)
    end

    test "requires url and secret" do
      org = create_organisation!()

      assert {:error, _} =
               OutboundWebhook
               |> Ash.Changeset.for_create(:create, %{organisation_id: org.id})
               |> Ash.create(authorize?: false)
    end

    test "rotates secret" do
      org = create_organisation!()

      {:ok, wh} =
        OutboundWebhook
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/wh",
          secret: "old_secret",
          events: [],
          organisation_id: org.id
        })
        |> Ash.create(authorize?: false)

      {:ok, rotated} =
        wh
        |> Ash.Changeset.for_update(:rotate_secret, %{secret: "new_secret"})
        |> Ash.update(authorize?: false)

      assert rotated.secret == "new_secret"
      assert Emakola.Security.FieldEncryption.encrypted?(rotated.secret_encrypted)
      assert {:ok, "new_secret"} = Emakola.Security.SecretStorage.outbound_webhook_secret(rotated)
    end
  end

  describe "WebhookDelivery" do
    test "creates and marks delivery as delivered" do
      org = create_organisation!()

      {:ok, wh} =
        OutboundWebhook
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/wh",
          secret: "secret",
          events: ["test"],
          organisation_id: org.id
        })
        |> Ash.create(authorize?: false)

      {:ok, delivery} =
        WebhookDelivery
        |> Ash.Changeset.for_create(:create, %{
          event_type: "test.event",
          payload: %{"data" => "test"},
          webhook_id: wh.id
        })
        |> Ash.create(authorize?: false)

      assert delivery.status == :pending

      {:ok, delivered} =
        delivery
        |> Ash.Changeset.for_update(:mark_delivered, %{response_status: 200, attempts: 1})
        |> Ash.update(authorize?: false)

      assert delivered.status == :delivered
      assert delivered.delivered_at
    end
  end

  describe "HMAC signing" do
    test "produces consistent HMAC-SHA256 signatures" do
      sig1 = WebhookDeliveryWorker.compute_hmac("secret", "12345", ~s({"event":"test"}))
      sig2 = WebhookDeliveryWorker.compute_hmac("secret", "12345", ~s({"event":"test"}))
      assert sig1 == sig2
    end

    test "different secrets produce different signatures" do
      sig1 = WebhookDeliveryWorker.compute_hmac("secret1", "12345", "body")
      sig2 = WebhookDeliveryWorker.compute_hmac("secret2", "12345", "body")
      assert sig1 != sig2
    end

    test "different timestamps produce different signatures" do
      sig1 = WebhookDeliveryWorker.compute_hmac("secret", "111", "body")
      sig2 = WebhookDeliveryWorker.compute_hmac("secret", "222", "body")
      assert sig1 != sig2
    end

    test "signature is hex-encoded lowercase" do
      sig = WebhookDeliveryWorker.compute_hmac("s", "t", "b")
      assert sig =~ ~r/^[0-9a-f]+$/
    end
  end

  describe "Demo mode" do
    test "demo mode is disabled by default" do
      refute Emakola.Demo.enabled?()
    end

    test "demo credentials are defined" do
      assert Emakola.Demo.demo_email() == "demo@emakola.com"
      assert is_binary(Emakola.Demo.demo_password())
    end
  end

  describe "edge cases" do
    test "webhook with empty events list" do
      org = create_organisation!()

      {:ok, wh} =
        OutboundWebhook
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/wh",
          secret: "secret",
          events: [],
          organisation_id: org.id
        })
        |> Ash.create(authorize?: false)

      assert wh.events == []
    end

    test "webhook payload with nested data" do
      org = create_organisation!()

      {:ok, wh} =
        OutboundWebhook
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/wh",
          secret: "s",
          events: ["test"],
          organisation_id: org.id
        })
        |> Ash.create(authorize?: false)

      nested = %{"level1" => %{"level2" => %{"level3" => [1, 2, 3]}}}

      {:ok, delivery} =
        WebhookDelivery
        |> Ash.Changeset.for_create(:create, %{
          event_type: "test",
          payload: nested,
          webhook_id: wh.id
        })
        |> Ash.create(authorize?: false)

      assert delivery.payload["level1"]["level2"]["level3"] == [1, 2, 3]
    end
  end
end
