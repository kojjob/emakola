defmodule Emakola.Notifications.Workers.PushNotificationWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.PushNotificationWorker

  setup :verify_on_exit!

  defp register_device!(merchant, store, token) do
    Emakola.Notifications.DeviceToken
    |> Ash.Changeset.for_create(:register, %{platform: :android, token: token},
      actor: merchant,
      tenant: store.id
    )
    |> Ash.create!()
  end

  test "sends a push to every device token registered for the order's store" do
    {merchant, store} = create_merchant_with_store!()
    second = create_merchant!()
    create_store_membership!(second, store, :staff)

    register_device!(merchant, store, "fcm-1")
    register_device!(second, store, "fcm-2")
    order = create_order!(store)

    expect(Emakola.PushProviderMock, :send_push, 2, fn token, notification ->
      assert token in ["fcm-1", "fcm-2"]
      assert notification.title =~ order.order_number
      assert notification.data["order_id"] == order.id
      {:ok, %{}}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "does not push to another store's devices" do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()

    register_device!(merchant_a, store_a, "fcm-a")
    register_device!(merchant_b, store_b, "fcm-b")
    order = create_order!(store_a)

    expect(Emakola.PushProviderMock, :send_push, 1, fn token, _notification ->
      assert token == "fcm-a"
      {:ok, %{}}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "prunes tokens FCM reports as unregistered" do
    {merchant, store} = create_merchant_with_store!()
    register_device!(merchant, store, "fcm-dead")
    order = create_order!(store)

    expect(Emakola.PushProviderMock, :send_push, fn "fcm-dead", _ ->
      {:error, :unregistered}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })

    assert [] ==
             Ash.read!(Emakola.Notifications.DeviceToken, authorize?: false, tenant: store.id)
  end

  test "pruning a token already deleted by a concurrent job still succeeds" do
    {merchant, store} = create_merchant_with_store!()
    dt = register_device!(merchant, store, "fcm-gone")
    order = create_order!(store)

    # Simulate the race: another job (or the device re-registering) deletes
    # the row between this worker's read and its prune attempt. The mock
    # callback runs exactly in that window.
    expect(Emakola.PushProviderMock, :send_push, fn "fcm-gone", _ ->
      Ash.destroy!(dt, authorize?: false, tenant: store.id)
      {:error, :unregistered}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "transient provider error does not prune and still succeeds" do
    {merchant, store} = create_merchant_with_store!()
    register_device!(merchant, store, "fcm-flaky")
    order = create_order!(store)

    expect(Emakola.PushProviderMock, :send_push, fn "fcm-flaky", _ ->
      {:error, {:fcm_error, 503, %{}}}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })

    assert [_] =
             Ash.read!(Emakola.Notifications.DeviceToken, authorize?: false, tenant: store.id)
  end

  test "no device tokens → succeeds without calling the provider" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "Dispatcher.dispatch enqueues a push job for order_placed" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    {:ok, _job} = Emakola.Notifications.Dispatcher.dispatch(order, :order_placed)

    assert_enqueued(
      worker: PushNotificationWorker,
      args: %{"order_id" => order.id, "event" => "order_placed"}
    )
  end

  test "Dispatcher.dispatch does NOT enqueue push for other events" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    {:ok, _job} = Emakola.Notifications.Dispatcher.dispatch(order, :order_shipped)

    refute_enqueued(worker: PushNotificationWorker)
  end
end
