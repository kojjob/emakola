defmodule Emakola.Notifications.Workers.ConnectionNotificationWorkerTest do
  use Emakola.DataCase, async: true

  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications.DeviceToken
  alias Emakola.Notifications.Workers.ConnectionNotificationWorker
  alias Emakola.Suppliers.Network

  setup :verify_on_exit!

  # ── Helpers ────────────────────────────────────────────────────

  defp create_wholesaler! do
    merchant = Factory.create_merchant!(%{phone: "+233240000001"})
    store = Factory.create_store!(%{name: "Kumasi Wholesale Depot"})
    Factory.create_store_membership!(merchant, store, :owner)
    {merchant, store}
  end

  defp create_reseller! do
    merchant = Factory.create_merchant!(%{phone: "+233240000002"})
    store = Factory.create_store!(%{name: "Accra Fashion Hub"})
    Factory.create_store_membership!(merchant, store, :owner)
    {merchant, store}
  end

  defp register_device!(merchant, store, token) do
    DeviceToken
    |> Ash.Changeset.for_create(:register, %{platform: :android, token: token},
      actor: merchant,
      tenant: store.id
    )
    |> Ash.create!()
  end

  defp request_connection!(wholesaler_store, reseller_store, reseller_merchant) do
    {:ok, connection} =
      Network.request(reseller_merchant, %{
        wholesaler_store_id: wholesaler_store.id,
        reseller_store_id: reseller_store.id,
        requested_by_store_id: reseller_store.id
      })

    connection
  end

  defp perform(connection_id, event) do
    ConnectionNotificationWorker.perform(%Oban.Job{
      args: %{"connection_id" => connection_id, "event" => event}
    })
  end

  # ── requested ──────────────────────────────────────────────────

  describe "requested" do
    test "notifies wholesaler owners on all three channels with reseller name" do
      {w_merchant, w_store} = create_wholesaler!()
      {r_merchant, r_store} = create_reseller!()
      register_device!(w_merchant, w_store, "fcm-wholesaler-1")

      connection = request_connection!(w_store, r_store, r_merchant)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233240000001"
        assert message =~ r_store.name
        {:ok, %{}}
      end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn to, template, params, _opts ->
        assert to == "+233240000001"
        assert template == "supply_connection_update"
        assert params.counterparty == r_store.name
        assert params.event == "requested"
        {:ok, %{}}
      end)

      Emakola.PushProviderMock
      |> expect(:send_push, fn token, notification ->
        assert token == "fcm-wholesaler-1"
        assert notification.body =~ r_store.name
        {:ok, %{}}
      end)

      assert :ok == perform(connection.id, "requested")
    end
  end

  # ── approved ───────────────────────────────────────────────────

  describe "approved" do
    test "notifies reseller owners, copy names the wholesaler" do
      {w_merchant, w_store} = create_wholesaler!()
      {r_merchant, r_store} = create_reseller!()
      register_device!(r_merchant, r_store, "fcm-reseller-1")

      connection = request_connection!(w_store, r_store, r_merchant)
      {:ok, connection} = Network.approve(w_merchant, connection)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233240000002"
        assert message =~ w_store.name
        {:ok, %{}}
      end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, "supply_connection_update", params, _opts ->
        assert params.counterparty == w_store.name
        assert params.event == "approved"
        {:ok, %{}}
      end)

      Emakola.PushProviderMock
      |> expect(:send_push, fn "fcm-reseller-1", notification ->
        assert notification.body =~ w_store.name
        {:ok, %{}}
      end)

      assert :ok == perform(connection.id, "approved")
    end
  end

  # ── rejected ───────────────────────────────────────────────────

  describe "rejected" do
    test "notifies reseller owners with declined copy" do
      {w_merchant, w_store} = create_wholesaler!()
      {r_merchant, r_store} = create_reseller!()
      register_device!(r_merchant, r_store, "fcm-reseller-2")

      connection = request_connection!(w_store, r_store, r_merchant)
      {:ok, connection} = Network.reject(w_merchant, connection, "Not accepting new resellers")

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233240000002"
        assert message =~ "declined"
        assert message =~ w_store.name
        {:ok, %{}}
      end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, "supply_connection_update", params, _opts ->
        assert params.counterparty == w_store.name
        assert params.event == "rejected"
        {:ok, %{}}
      end)

      Emakola.PushProviderMock
      |> expect(:send_push, fn "fcm-reseller-2", notification ->
        assert notification.title == "Connection declined"
        assert notification.body =~ w_store.name
        {:ok, %{}}
      end)

      assert :ok == perform(connection.id, "rejected")
    end
  end

  # ── missing phone ──────────────────────────────────────────────

  describe "missing phone" do
    test "skips SMS and WhatsApp but still pushes" do
      w_merchant = Factory.create_merchant!()
      w_store = Factory.create_store!(%{name: "No Phone Wholesale"})
      Factory.create_store_membership!(w_merchant, w_store, :owner)
      register_device!(w_merchant, w_store, "fcm-no-phone")

      {r_merchant, r_store} = create_reseller!()
      connection = request_connection!(w_store, r_store, r_merchant)

      Emakola.PushProviderMock
      |> expect(:send_push, fn "fcm-no-phone", _notification -> {:ok, %{}} end)

      assert :ok == perform(connection.id, "requested")
    end
  end

  # ── channel failure isolation ───────────────────────────────────

  describe "channel failure isolation" do
    test "one channel raising does not block the others and the job returns :ok" do
      {w_merchant, w_store} = create_wholesaler!()
      {r_merchant, r_store} = create_reseller!()
      register_device!(w_merchant, w_store, "fcm-wholesaler-3")

      connection = request_connection!(w_store, r_store, r_merchant)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _message, _opts -> raise "sms provider down" end)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts -> {:ok, %{}} end)

      Emakola.PushProviderMock
      |> expect(:send_push, fn _token, _notification -> {:ok, %{}} end)

      assert :ok == perform(connection.id, "requested")
    end
  end

  # ── missing connection ───────────────────────────────────────────

  describe "missing connection" do
    test "returns :ok and sends nothing" do
      assert :ok == perform(Ash.UUID.generate(), "requested")
    end
  end
end
