defmodule EmakolaWeb.Platform.DomainLive.IndexTest do
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory

  alias Emakola.Stores

  setup %{conn: conn} do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    {conn, _user, _session} = setup_platform_staff(conn)
    store = create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-plat"})
    {:ok, conn: conn, store: store}
  end

  defp claim!(store, host) do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    d
  end

  describe "the queue" do
    test "lists custom domains awaiting review", %{conn: conn, store: store} do
      domain = claim!(store, "kentekingdom.com")

      {:ok, _view, html} = live(conn, ~p"/platform/domains")

      assert html =~ "kentekingdom.com"
      assert html =~ store.name
      assert html =~ domain.id
    end

    test "ignores store subdomains entirely", %{conn: conn, store: store} do
      {:ok, _} =
        Stores.create_store_domain(%{store_id: store.id, host: "kente-kingdom-plat.makola.io"},
          authorize?: false
        )

      {:ok, _view, html} = live(conn, ~p"/platform/domains")
      refute html =~ "kente-kingdom-plat.makola.io"
    end

    test "shows what the merchant was told to add", %{conn: conn, store: store} do
      _ = claim!(store, "kentekingdom.com")

      {:ok, _view, html} = live(conn, ~p"/platform/domains")

      # Staff cannot help over WhatsApp without seeing the same records.
      assert html =~ "66.241.124.228"
      assert html =~ "2a09:8280:1::126:6f75:0"
    end
  end

  describe "approving" do
    test "moves the domain into verification", %{conn: conn, store: store} do
      domain = claim!(store, "kentekingdom.com")

      {:ok, view, _} = live(conn, ~p"/platform/domains")
      render_click(element(view, ~s|button[phx-value-id="#{domain.id}"][phx-click="approve"]|))

      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :verifying
    end

    test "is recorded in the audit log", %{conn: conn, store: store} do
      domain = claim!(store, "kentekingdom.com")

      {:ok, view, _} = live(conn, ~p"/platform/domains")
      render_click(element(view, ~s|button[phx-value-id="#{domain.id}"][phx-click="approve"]|))

      {:ok, page} = Emakola.Accounts.list_platform_audit_logs(authorize?: false)
      assert Enum.any?(page.results, &(&1.action == :domain_approved))
    end

    # This is what lets H land before the certificate worker exists.
    test "never talks to Fly", %{conn: conn, store: store} do
      Application.put_env(:emakola, :fly_certs, Emakola.Infra.FlyCertsMock)
      on_exit(fn -> Application.delete_env(:emakola, :fly_certs) end)

      domain = claim!(store, "kentekingdom.com")

      {:ok, view, _} = live(conn, ~p"/platform/domains")
      # No Mox expectations: any call would fail verify_on_exit!.
      render_click(element(view, ~s|button[phx-value-id="#{domain.id}"][phx-click="approve"]|))

      assert {:ok, %{status: :verifying}} =
               Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
    end
  end

  describe "rejecting" do
    test "retires the domain with the staff reason", %{conn: conn, store: store} do
      domain = claim!(store, "kentekingdom.com")

      {:ok, view, _} = live(conn, ~p"/platform/domains")
      render_click(element(view, ~s|button[phx-value-id="#{domain.id}"][phx-click="reject"]|))

      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :expired
      assert reloaded.status_reason
    end

    test "frees the host for someone else", %{conn: conn, store: store} do
      domain = claim!(store, "nike.com")
      other = create_store!(%{name: "Other", slug: "other-store-plat"})

      {:ok, view, _} = live(conn, ~p"/platform/domains")
      render_click(element(view, ~s|button[phx-value-id="#{domain.id}"][phx-click="reject"]|))

      assert {:ok, _} =
               Stores.claim_custom_domain(%{store_id: other.id, host: "nike.com"},
                 authorize?: false
               )
    end
  end

  describe "access" do
    test "a signed-out visitor cannot reach it" do
      assert {:error, {:redirect, %{to: path}}} = live(build_conn(), ~p"/platform/domains")
      assert path =~ "/platform"
    end
  end
end
