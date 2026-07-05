defmodule EmakolaWeb.Platform.VerificationLiveTest do
  @moduledoc """
  Platform KYC review: the queue lists submissions (gated by :manage_merchants);
  the detail page approves (awards verified + audits + notifies) or rejects
  (requires a reason), and shows documents via presigned URLs.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Mox
  import Phoenix.LiveViewTest

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Factory
  alias Emakola.Notifications.Workers.VerificationStatusNotificationWorker, as: Worker
  alias Emakola.Stores

  setup :set_mox_global

  setup %{conn: conn} do
    stub(Emakola.StorageMock, :presigned_url, fn _key, _opts ->
      {:ok, "https://signed.example/doc"}
    end)

    {conn, user, _session} = setup_platform_staff(conn)
    store = Factory.create_store!(%{name: "Kente Co"})

    {:ok, verification} =
      Stores.submit_store_verification(
        %{
          store_id: store.id,
          business_name: "Kente Trades Ltd",
          id_type: :ghana_card,
          id_number: "GHA-1",
          id_document_key: "verifications/#{store.id}/id.png"
        },
        authorize?: false
      )

    %{conn: conn, user: user, store: store, verification: verification}
  end

  defp verification_audit(store_id) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.action in [:verification_approved, :verification_rejected]))
  end

  describe "Index" do
    test "lists pending submissions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/verifications")
      assert html =~ "Kente Co"
      assert html =~ "Kente Trades Ltd"
    end

    test "staff without :manage_merchants is redirected to /platform", %{conn: conn} do
      {conn, _u, _s} = setup_platform_staff(conn, permissions: [:view_audit_log])
      assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/verifications")
    end
  end

  describe "Show" do
    test "renders fields and a presigned document link", %{conn: conn, verification: v} do
      {:ok, _view, html} = live(conn, ~p"/platform/verifications/#{v.id}")
      assert html =~ "Kente Trades Ltd"
      assert html =~ "Ghana Card"
      assert html =~ "signed.example"
    end

    test "approve marks approved, awards verified, audits, and enqueues a notification", %{
      conn: conn,
      user: user,
      store: store,
      verification: v
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications/#{v.id}")
      assert view |> element("button", "Approve") |> render_click() =~ "Approved"

      assert {:ok, %{status: :approved}} =
               Stores.get_store_verification(store.id, authorize?: false)

      assert {:ok, %{verified: true}} = Stores.get_store(store.id, authorize?: false)

      assert [entry] = verification_audit(store.id)
      assert entry.action == :verification_approved
      assert entry.actor_id == user.id
      assert entry.metadata["store_id"] == store.id

      assert_enqueued(
        worker: Worker,
        args: %{"store_id" => store.id, "event" => "verification_approved"}
      )
    end

    test "reject requires a reason, records it, and leaves verified false", %{
      conn: conn,
      store: store,
      verification: v
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications/#{v.id}")

      view |> element("button", "Reject") |> render_click()
      assert view |> form("form", reason: "") |> render_submit() =~ "A reason is required"

      assert view |> form("form", reason: "Blurry ID") |> render_submit() =~ "Rejected"

      assert {:ok, %{status: :rejected, review_reason: "Blurry ID"}} =
               Stores.get_store_verification(store.id, authorize?: false)

      assert {:ok, %{verified: false}} = Stores.get_store(store.id, authorize?: false)
    end
  end
end
