defmodule Emakola.Notifications.Workers.AnnouncementPublishWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker, as: Worker

  defp announcement!(overrides) do
    {:ok, ann} =
      Notifications.create_announcement(
        Map.merge(
          %{
            title: "Hi",
            body: "Body",
            channels: [:banner, :sms],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          overrides
        ),
        authorize?: false
      )

    ann
  end

  test "enqueue schedules a job at publish_at" do
    {:ok, _} = Worker.enqueue("abc", ~U[2026-07-01 00:00:00Z])
    assert_enqueued(worker: Worker, args: %{"announcement_id" => "abc"})
  end

  test "perform publishes a scheduled announcement and enqueues one delivery per target store" do
    store_a = Factory.create_store!()
    store_b = Factory.create_store!()
    ann = announcement!(%{channels: [:sms], audience: :all})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})

    {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
    assert reloaded.status == :published

    assert_enqueued(
      worker: AnnouncementDeliveryWorker,
      args: %{"announcement_id" => ann.id, "store_id" => store_a.id}
    )

    assert_enqueued(
      worker: AnnouncementDeliveryWorker,
      args: %{"announcement_id" => ann.id, "store_id" => store_b.id}
    )
  end

  test "audience :active skips non-live stores" do
    live = Factory.create_store!()

    {:ok, archived} =
      Emakola.Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    ann = announcement!(%{channels: [:sms], audience: :active})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})

    assert_enqueued(
      worker: AnnouncementDeliveryWorker,
      args: %{"announcement_id" => ann.id, "store_id" => live.id}
    )

    refute_enqueued(
      worker: AnnouncementDeliveryWorker,
      args: %{"announcement_id" => ann.id, "store_id" => archived.id}
    )
  end

  test "banner-only announcements enqueue no delivery jobs" do
    Factory.create_store!()
    ann = announcement!(%{channels: [:banner]})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})
    refute_enqueued(worker: AnnouncementDeliveryWorker)
  end

  test "a canceled announcement is a no-op" do
    Factory.create_store!()
    ann = announcement!(%{channels: [:sms]})
    {:ok, _} = Notifications.cancel_announcement(ann, authorize?: false)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})
    refute_enqueued(worker: AnnouncementDeliveryWorker)
    {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
    assert reloaded.status == :canceled
  end
end
