defmodule EmakolaWeb.Admin.StoreAddressLiveTest do
  # async: false — these mutate the :store_subdomain_base application env to
  # exercise the panel as if the subdomain feature were switched on.
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  alias Emakola.Stores

  setup %{conn: conn} do
    prev = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:emakola, :store_subdomain_base, prev),
        else: Application.delete_env(:emakola, :store_subdomain_base)
    end)

    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  test "redirects to login when unauthenticated" do
    assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
             live(build_conn(), ~p"/admin/settings/address")
  end

  test "renders the claim form with the apex suffix", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/settings/address")
    assert html =~ "Your storefront address"
    assert html =~ ".makola.io"
  end

  test "claims a subdomain for the store", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/address")

    html = view |> form("form", %{"label" => "ama-kitchen"}) |> render_submit()

    assert html =~ "ama-kitchen.makola.io"
    assert {:ok, [domain]} = Stores.list_store_domains(store.id, authorize?: false)
    assert domain.host == "ama-kitchen.makola.io"
    assert domain.type == :subdomain
  end

  test "rejects a reserved subdomain label", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/address")

    html = view |> form("form", %{"label" => "admin"}) |> render_submit()

    assert html =~ "reserved"
  end

  test "toggles serve-in-place on the claimed domain", %{conn: conn, store: store} do
    {:ok, _} =
      Stores.create_store_domain(%{store_id: store.id, host: "ama.makola.io", primary?: true},
        authorize?: false
      )

    {:ok, view, _html} = live(conn, ~p"/admin/settings/address")
    view |> element("button[phx-click=toggle_serve]") |> render_click()

    assert {:ok, [domain]} = Stores.list_store_domains(store.id, authorize?: false)
    assert domain.serve_in_place? == true
  end

  test "shows a coming-soon notice when the feature is unconfigured", %{conn: conn} do
    Application.delete_env(:emakola, :store_subdomain_base)
    {:ok, _view, html} = live(conn, ~p"/admin/settings/address")
    assert html =~ "coming soon"
  end
end
