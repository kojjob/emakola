defmodule EmakolaWeb.HostRoutingTest do
  @moduledoc """
  Regression for the storefront reload-loop flicker: the storefront must be
  routed BY HOST so the browser address-bar URL matches the mounted LiveView.

  `<slug>.makola.io/` mounts StoreLive at root (address bar stays "/", and the
  router maps "/" → StoreLive on that host); `makola.io/` keeps mounting the
  apex LandingLive. Before this change the storefront was served-in-place via
  path rewriting, so LiveView's client saw "/" map to LandingLive (not its
  StoreLive) and force-reloaded forever.

  async: false because it mutates the global :store_subdomain_base app env.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    previous = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if previous do
        Application.put_env(:emakola, :store_subdomain_base, previous)
      else
        Application.delete_env(:emakola, :store_subdomain_base)
      end
    end)

    {_merchant, store} = Factory.create_merchant_with_store!(%{name: "Kente Kingdom"})
    %{store: store}
  end

  describe "GET / by host" do
    test "a store subdomain renders the storefront (not the landing page)", %{
      conn: conn,
      store: store
    } do
      conn = %{conn | host: "#{store.slug}.makola.io"}

      html = conn |> get("/") |> html_response(200)

      assert html =~ store.name
      refute html =~ "Start selling — free"
    end

    test "the apex host renders the landing page", %{conn: conn} do
      conn = %{conn | host: "makola.io"}

      html = conn |> get("/") |> html_response(200)

      assert html =~ "Start selling — free"
    end
  end

  describe "storefront LiveView mounted by host" do
    test "a store subdomain connects and renders the cart without redirecting", %{
      conn: conn,
      store: store
    } do
      conn = %{conn | host: "#{store.slug}.makola.io"}

      {:ok, view, html} = live(conn, "/cart")

      # Store resolved from host (no redirect-loop back to "/")
      refute_redirected(view, "/")
      assert html =~ "empty" or html =~ "Shopping Bag"
    end
  end

  describe "a host with no store" do
    test "GET /cart redirects to the ABSOLUTE apex root (not relative / — that would loop)",
         %{conn: conn} do
      conn = %{conn | host: "makola.io"}

      assert {:error, {:redirect, %{to: to}}} = live(conn, "/cart")
      assert to == EmakolaWeb.Endpoint.url() <> "/"
    end
  end
end
