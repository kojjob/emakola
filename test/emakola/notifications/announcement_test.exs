defmodule Emakola.Notifications.AnnouncementTest do
  @moduledoc """
  Platform broadcast announcement: scheduling, the derived `:active_for_store`
  window/audience query, cancel, and idempotent per-merchant dismissal.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Notifications

  defp valid_attrs(overrides) do
    Map.merge(
      %{
        title: "Scheduled maintenance",
        body: "We will be down Sunday 2am.",
        channels: [:banner, :email],
        audience: :all,
        publish_at: ~U[2026-06-20 00:00:00Z]
      },
      overrides
    )
  end

  defp create!(overrides \\ %{}) do
    {:ok, ann} = Notifications.create_announcement(valid_attrs(overrides), authorize?: false)
    ann
  end

  describe "create_announcement" do
    test "defaults to :scheduled status and :info severity" do
      ann = create!()
      assert ann.status == :scheduled
      assert ann.severity == :info
      assert ann.channels == [:banner, :email]
    end

    test "requires at least one channel" do
      assert {:error, _} =
               Notifications.create_announcement(valid_attrs(%{channels: []}), authorize?: false)
    end
  end

  describe "publish / cancel" do
    test "publish flips status to :published" do
      ann = create!()
      {:ok, published} = Notifications.publish_announcement(ann, authorize?: false)
      assert published.status == :published
    end

    test "cancel flips status to :canceled" do
      ann = create!()
      {:ok, canceled} = Notifications.cancel_announcement(ann, authorize?: false)
      assert canceled.status == :canceled
    end
  end

  describe "active_for_store (derived window + audience)" do
    @now ~U[2026-06-23 12:00:00Z]

    defp publish!(overrides) do
      overrides
      |> create!()
      |> then(&elem(Notifications.publish_announcement(&1, authorize?: false), 1))
    end

    defp active_ids(store_live) do
      {:ok, list} = Notifications.list_active_announcements(store_live, @now, authorize?: false)
      Enum.map(list, & &1.id)
    end

    test "includes a published, in-window, audience :all announcement" do
      ann = publish!(%{audience: :all, publish_at: ~U[2026-06-22 00:00:00Z]})
      assert ann.id in active_ids(false)
    end

    test "excludes scheduled (not yet published) announcements" do
      ann = create!(%{publish_at: ~U[2026-06-22 00:00:00Z]})
      refute ann.id in active_ids(true)
    end

    test "excludes announcements whose expires_at has passed" do
      ann =
        publish!(%{publish_at: ~U[2026-06-20 00:00:00Z], expires_at: ~U[2026-06-22 00:00:00Z]})

      refute ann.id in active_ids(true)
    end

    test "audience :active shows only when the store is live" do
      ann = publish!(%{audience: :active, publish_at: ~U[2026-06-22 00:00:00Z]})
      refute ann.id in active_ids(false)
      assert ann.id in active_ids(true)
    end
  end

  describe "dismissals" do
    test "dismiss is an idempotent upsert; ids are listed per merchant" do
      ann = create!()
      merchant_id = Ash.UUID.generate()

      {:ok, _} =
        Notifications.dismiss_announcement(
          %{announcement_id: ann.id, merchant_id: merchant_id},
          authorize?: false
        )

      {:ok, _} =
        Notifications.dismiss_announcement(
          %{announcement_id: ann.id, merchant_id: merchant_id},
          authorize?: false
        )

      {:ok, dismissals} =
        Notifications.list_dismissed_announcement_ids(merchant_id, authorize?: false)

      assert Enum.map(dismissals, & &1.announcement_id) == [ann.id]
    end
  end
end
