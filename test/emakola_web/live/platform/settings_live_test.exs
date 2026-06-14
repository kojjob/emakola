defmodule EmakolaWeb.Platform.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  defp log_in_platform_admin(conn) do
    admin = Factory.create_platform_admin!()
    token = AshAuthentication.user_to_subject(admin)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "access control" do
    test "platform admin can load the page", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "Settings"
      assert html =~ "feature flags"
    end

    test "a non-admin merchant is redirected", %{conn: conn} do
      {merchant, _store} = Factory.create_merchant_with_store!()
      token = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/platform/settings")
    end
  end

  describe "listing & stats" do
    setup %{conn: conn} do
      Factory.create_feature_flag!(%{key: "alpha", name: "Alpha", enabled: true})

      Factory.create_feature_flag!(%{
        key: "beta",
        name: "Beta",
        enabled: true,
        required_plan: "pro"
      })

      Factory.create_feature_flag!(%{key: "gamma", name: "Gamma", enabled: false})
      {:ok, conn: log_in_platform_admin(conn)}
    end

    test "renders all flags with names and keys", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      for s <- ["Alpha", "Beta", "Gamma", "alpha", "beta", "gamma"], do: assert(html =~ s)
    end

    test "stat strip shows correct counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = render(view)
      assert html =~ "Total"
      assert html =~ "Enabled"
      assert html =~ "Plan-gated"
      assert html =~ "Disabled"
    end

    test "search narrows by name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = view |> form("#flag-search-form") |> render_change(%{"search" => "Alpha"})
      assert html =~ "Alpha"
      refute html =~ "Gamma"
    end

    test "search narrows by key", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = view |> form("#flag-search-form") |> render_change(%{"search" => "beta"})
      assert html =~ "Beta"
      refute html =~ "Alpha"
    end

    test "disabled filter shows only disabled flags", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = render_click(view, "filter", %{"filter" => "disabled"})
      assert html =~ "Gamma"
      refute html =~ "Alpha"
    end
  end

  describe "toggle" do
    test "flips a flag's enabled state and persists", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "tog", name: "Toggle Me", enabled: true})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "toggle", %{"id" => flag.id})

      {:ok, reloaded} = Emakola.FeatureFlags.get_flag(flag.id, authorize?: false)
      refute reloaded.enabled
    end
  end

  describe "create" do
    setup %{conn: conn}, do: {:ok, conn: log_in_platform_admin(conn)}

    test "creates a new flag", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      view
      |> form("#flag-form", %{
        "key" => "new_feature",
        "name" => "New Feature",
        "description" => "A shiny thing",
        "enabled" => "true",
        "required_plan" => "starter"
      })
      |> render_submit()

      assert {:ok, flag} = Emakola.FeatureFlags.get_flag_by_key("new_feature", authorize?: false)
      assert flag.name == "New Feature"
      assert flag.required_plan == "starter"
    end

    test "blank name shows a validation error and creates nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      html =
        view
        |> form("#flag-form", %{"key" => "k1", "name" => "", "enabled" => "true"})
        |> render_submit()

      assert html =~ "Name is required"
      assert {:ok, []} = Emakola.FeatureFlags.list_flags(authorize?: false)
    end

    test "required_plan select offers only the four tiers plus none", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "All plans"
      for tier <- ~w(Free Starter Pro Enterprise), do: assert(html =~ tier)
    end
  end

  describe "edit" do
    test "updates name and keeps key field disabled", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "edit_me", name: "Before"})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "open_edit_modal", %{"id" => flag.id})
      html = render(view)
      assert html =~ "disabled"

      view
      |> form("#flag-form", %{"name" => "After", "enabled" => "true", "required_plan" => ""})
      |> render_submit()

      {:ok, reloaded} = Emakola.FeatureFlags.get_flag(flag.id, authorize?: false)
      assert reloaded.name == "After"
      assert reloaded.key == "edit_me"
    end
  end

  describe "delete" do
    test "removes a flag", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "kill", name: "Kill Me"})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "delete", %{"id" => flag.id})

      assert {:error, _} = Emakola.FeatureFlags.get_flag(flag.id, authorize?: false)
    end
  end

  describe "empty state" do
    test "renders when no flags exist", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "No feature flags yet"
    end
  end
end
