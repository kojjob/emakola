defmodule EmakolaWeb.Admin.StoreDomainLiveTest do
  @moduledoc """
  Merchants here are often not strong readers, and editing DNS at a registrar
  is the most technical thing this product ever asks of one. So these tests
  pin the affordances that carry the meaning — the records themselves, the
  copy buttons, the WhatsApp hand-off — not the prose around them.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  alias Emakola.Stores

  setup %{conn: conn} do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    {:ok, conn: conn, store: store}
  end

  defp claim!(conn, host) do
    {:ok, view, _} = live(conn, ~p"/admin/settings/domain")
    render_submit(element(view, "#claim-domain-form"), %{"host" => host})
    view
  end

  describe "claiming" do
    test "an apex claim creates the domain and its www sibling", %{conn: conn, store: store} do
      _ = claim!(conn, "kentekingdom.com")

      {:ok, domains} = Stores.list_store_domains(store.id, authorize?: false)
      hosts = domains |> Enum.map(& &1.host) |> Enum.sort()

      assert hosts == ["kentekingdom.com", "www.kentekingdom.com"]
    end

    test "a subdomain claim creates one row", %{conn: conn, store: store} do
      _ = claim!(conn, "shop.kentekingdom.com")

      {:ok, domains} = Stores.list_store_domains(store.id, authorize?: false)
      assert Enum.map(domains, & &1.host) == ["shop.kentekingdom.com"]
    end

    test "a platform host is refused and creates nothing", %{conn: conn, store: store} do
      view = claim!(conn, "emakola.fly.dev")

      assert render(view) =~ "not available"
      assert {:ok, []} = Stores.list_store_domains(store.id, authorize?: false)
    end
  end

  describe "copying a DNS record" do
    # The whole point of the DNS table is that a merchant copies these values
    # into their registrar. The control pushed a "copy" event this LiveView
    # never handled, and an unmatched event takes the page down with it — so
    # the button both failed to copy and killed the page a merchant was
    # reading instructions from.
    test "the copy control does not push an event nothing handles", %{conn: conn} do
      html = conn |> claim!("kentekingdom.com") |> render()

      refute html =~ ~s(phx-click="copy")
      assert html =~ "copy-to-clipboard"
    end
  end

  describe "the DNS instructions" do
    test "an apex domain shows all three records, including AAAA", %{conn: conn} do
      html = conn |> claim!("kentekingdom.com") |> render()

      # The AAAA row is the one merchants skip, and skipping it is why a
      # certificate never issues. It must be on screen, not in a footnote.
      assert html =~ "AAAA"
      assert html =~ "2a09:8280:1::126:6f75:0"
      assert html =~ "66.241.124.228"
      assert html =~ "emakola.fly.dev"
    end

    test "a subdomain shows only its CNAME", %{conn: conn} do
      html = conn |> claim!("shop.kentekingdom.com") |> render()

      assert html =~ "CNAME"
      # Assert on the IPv6 VALUE, not the string "AAAA" — base64 in
      # data-phx-session contains literal AAAA runs and makes that unreliable.
      refute html =~ "2a09:8280"
      refute html =~ "66.241.124.228"
    end

    test "every record can be copied without typing", %{conn: conn} do
      html = conn |> claim!("kentekingdom.com") |> render()
      assert html =~ "phx-click=\"copy\"" or html =~ "data-copy"
    end

    test "the records can be sent to WhatsApp", %{conn: conn} do
      # The merchant often does not hold the registrar login themselves.
      html = conn |> claim!("kentekingdom.com") |> render()
      assert html =~ "wa.me" or html =~ "whatsapp"
    end
  end

  describe "each state tells the merchant what is happening" do
    test "waiting", %{conn: conn} do
      html = conn |> claim!("kentekingdom.com") |> render()
      assert html =~ "hero-" and html =~ "kentekingdom.com"
    end

    test "checking", %{conn: conn, store: store} do
      {:ok, d} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
          authorize?: false
        )

      {:ok, _} = Stores.request_domain_verification(d, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/domain")
      assert html =~ "Checking"
    end

    test "live", %{conn: conn, store: store} do
      {:ok, d} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
          authorize?: false
        )

      {:ok, d} = Stores.request_domain_verification(d, authorize?: false)
      {:ok, _} = Stores.mark_domain_active(d, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/domain")
      assert html =~ "kentekingdom.com"
      assert html =~ "hero-check"
    end

    test "a problem shows the reason, not a status code", %{conn: conn, store: store} do
      {:ok, d} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
          authorize?: false
        )

      {:ok, d} = Stores.request_domain_verification(d, authorize?: false)

      {:ok, _} =
        Stores.record_domain_check(d, %{message: "no AAAA record found"}, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/domain")
      assert html =~ "no AAAA record found"
    end
  end

  describe "access" do
    test "signed-out merchants are sent to login" do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(build_conn(), ~p"/admin/settings/domain")
    end
  end

  # StoreAddressLive shipped reachable only by typing its URL. Don't repeat that.
  describe "discoverability" do
    test "settings offers a Domain tab that links here", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "switch_tab"
      assert html =~ "Domain"

      html = render_click(element(view, ~s|button[phx-value-tab="domain"]|))
      assert html =~ "/admin/settings/domain"
    end
  end
end
