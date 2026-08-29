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
      {:ok, view, html} = live(conn, ~p"/platform/verifications")
      assert html =~ "Kente Co"
      assert html =~ "Kente Trades Ltd"
      assert has_element?(view, "#platform-verifications[phx-update='stream'][data-count='1']")
    end

    test "status filters reset the verification stream", %{conn: conn, verification: verification} do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications")
      assert has_element?(view, "#verification-#{verification.id}")

      view |> element("#verification-filter-approved") |> render_click()

      assert has_element?(view, "#platform-verifications[data-count='0']")
      assert has_element?(view, "#platform-verifications-empty")
      refute has_element?(view, "#verification-#{verification.id}")

      view |> element("#verification-filter-pending") |> render_click()

      assert has_element?(view, "#platform-verifications[data-count='1']")
      assert has_element?(view, "#verification-#{verification.id}")
    end

    test "staff without :manage_merchants is redirected to /platform", %{conn: conn} do
      {conn, _u, _s} = setup_platform_staff(conn, permissions: [:view_audit_log])
      assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/verifications")
    end

    test "the first submission is selected and the panel shows the case", %{
      conn: conn,
      verification: verification
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      assert has_element?(view, "#verification-#{verification.id}[data-selected]")
      assert has_element?(view, "#verification-panel", "Kente Trades Ltd")
      assert has_element?(view, "#verification-panel", "Ghana Card")
      assert has_element?(view, ~s(#verification-panel img[src="https://signed.example/doc"]))
    end

    test "clicking a row switches the panel", %{conn: conn, verification: verification} do
      other_store = Factory.create_store!(%{name: "Basket Co"})

      {:ok, other} =
        Stores.submit_store_verification(
          %{
            store_id: other_store.id,
            business_name: "Ayine Weaving Co",
            id_type: :passport,
            id_number: "G-2",
            id_document_key: "verifications/#{other_store.id}/id.png"
          },
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      view |> element("#verification-#{verification.id}") |> render_click()

      assert has_element?(view, "#verification-#{verification.id}[data-selected]")
      assert has_element?(view, "#verification-panel", "Kente Trades Ltd")

      view |> element("#verification-#{other.id}") |> render_click()

      assert has_element?(view, "#verification-#{other.id}[data-selected]")
      refute has_element?(view, "#verification-#{verification.id}[data-selected]")
      assert has_element?(view, "#verification-panel", "Ayine Weaving Co")
    end

    test "a filter with no submissions hides the panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      view |> element("#verification-filter-approved") |> render_click()

      refute has_element?(view, "#verification-panel")
      assert has_element?(view, "#platform-verifications-empty")
    end

    test "approve from the panel awards verified, audits, and enqueues", %{
      conn: conn,
      user: user,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      view |> element("#panel-approve") |> render_click()

      assert {:ok, %{status: :approved}} =
               Stores.get_store_verification(store.id, authorize?: false)

      assert {:ok, %{verified: true}} = Stores.get_store(store.id, authorize?: false)
      assert has_element?(view, "#verification-panel", "Approved")

      assert [entry] = verification_audit(store.id)
      assert entry.action == :verification_approved
      assert entry.actor_id == user.id

      assert_enqueued(
        worker: Worker,
        args: %{"store_id" => store.id, "event" => "verification_approved"}
      )
    end

    test "inline reject requires a reason and records it", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      assert has_element?(view, "#verification-reject-form")

      view |> form("#verification-reject-form", reason: "") |> render_submit()
      assert has_element?(view, "#flash-error", "A reason is required")

      view |> form("#verification-reject-form", reason: "Blurry ID") |> render_submit()

      assert {:ok, %{status: :rejected, review_reason: "Blurry ID"}} =
               Stores.get_store_verification(store.id, authorize?: false)

      assert {:ok, %{verified: false}} = Stores.get_store(store.id, authorize?: false)
      assert has_element?(view, "#panel-review-banner", "Blurry ID")
      refute has_element?(view, "#verification-reject-form")
    end

    test "j and k walk the queue selection", %{conn: conn, verification: verification} do
      other_store = Factory.create_store!(%{name: "Newer Co"})

      {:ok, newer} =
        Stores.submit_store_verification(
          %{
            store_id: other_store.id,
            business_name: "Newer Ventures",
            id_type: :voter_id,
            id_number: "V-3",
            id_document_key: "verifications/#{other_store.id}/id.png"
          },
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/verifications")

      # Oldest-first queue: `verification` sits at the top and is selected.
      assert has_element?(view, "#verification-#{verification.id}[data-selected]")

      render_click(view, "queue_key", %{"key" => "j"})
      assert has_element?(view, "#verification-#{newer.id}[data-selected]")

      # j at the bottom clamps.
      render_click(view, "queue_key", %{"key" => "j"})
      assert has_element?(view, "#verification-#{newer.id}[data-selected]")

      render_click(view, "queue_key", %{"key" => "k"})
      assert has_element?(view, "#verification-#{verification.id}[data-selected]")

      # k at the top clamps.
      render_click(view, "queue_key", %{"key" => "k"})
      assert has_element?(view, "#verification-#{verification.id}[data-selected]")
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
      assert has_element?(view, "#verification-reject-form")

      view |> form("#verification-reject-form", reason: "") |> render_submit()
      assert has_element?(view, "#flash-error", "A reason is required")

      view |> form("#verification-reject-form", reason: "Blurry ID") |> render_submit()
      assert has_element?(view, "#verification-status", "Rejected")

      assert {:ok, %{status: :rejected, review_reason: "Blurry ID"}} =
               Stores.get_store_verification(store.id, authorize?: false)

      assert {:ok, %{verified: false}} = Stores.get_store(store.id, authorize?: false)
    end
  end
end
