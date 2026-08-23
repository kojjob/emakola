defmodule EmakolaWeb.Platform.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  # Log in a platform staff member (owner by default) and return the conn.
  defp log_in_platform_admin(conn) do
    {conn, _user, _session} = setup_platform_staff(conn)
    conn
  end

  describe "permission gating" do
    test "owner can load the page", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "Settings"
      assert html =~ "feature flags"
    end

    test "staff with :manage_settings can load the page", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_settings])
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "Settings"
    end

    test "staff without :manage_settings is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/settings")

      assert flash["error"] =~ "permission"
    end
  end

  describe "listing & stats" do
    setup %{conn: conn} do
      alpha = Factory.create_feature_flag!(%{key: "alpha", name: "Alpha", enabled: true})

      beta =
        Factory.create_feature_flag!(%{
          key: "beta",
          name: "Beta",
          enabled: true,
          required_plan: "pro"
        })

      gamma = Factory.create_feature_flag!(%{key: "gamma", name: "Gamma", enabled: false})
      {:ok, conn: log_in_platform_admin(conn), alpha: alpha, beta: beta, gamma: gamma}
    end

    test "renders all flags with names and keys", %{
      conn: conn,
      alpha: alpha,
      beta: beta,
      gamma: gamma
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      assert has_element?(view, "#flags-#{alpha.id}", "Alpha")
      assert has_element?(view, "#flags-#{beta.id}", "Beta")
      assert has_element?(view, "#flags-#{gamma.id}", "Gamma")
    end

    test "stat strip shows correct counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = render(view)
      assert html =~ "Total"
      assert html =~ "Enabled"
      assert html =~ "Plan-gated"
      assert html =~ "Disabled"
    end

    test "search narrows by name", %{conn: conn, alpha: alpha, gamma: gamma} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      view |> form("#flag-search-form") |> render_change(%{"search" => "Alpha"})
      assert has_element?(view, "#flags-#{alpha.id}")
      refute has_element?(view, "#flags-#{gamma.id}")
    end

    test "search narrows by key", %{conn: conn, alpha: alpha, beta: beta} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      view |> form("#flag-search-form") |> render_change(%{"search" => "beta"})
      assert has_element?(view, "#flags-#{beta.id}")
      refute has_element?(view, "#flags-#{alpha.id}")
    end

    test "disabled filter shows only disabled flags", %{conn: conn, alpha: alpha, gamma: gamma} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      render_click(view, "filter", %{"filter" => "disabled"})
      assert has_element?(view, "#flags-#{gamma.id}")
      refute has_element?(view, "#flags-#{alpha.id}")
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

    # One click here changes what every merchant on the platform can see, and
    # it fired with no confirmation — while Delete, far less reachable, got a
    # full modal.
    test "turning a live flag off asks first, and names the flag", %{conn: conn} do
      flag =
        Factory.create_feature_flag!(%{key: "live_one", name: "Dropship network", enabled: true})

      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      toggle = view |> element("#flags-#{flag.id} button[phx-click='toggle']") |> render()

      assert toggle =~ "data-confirm"
      assert toggle =~ "Dropship network"
      assert toggle =~ "off"
    end

    test "turning a flag on asks first too, worded for switching on", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "dark_one", name: "Susu plans", enabled: false})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      toggle = view |> element("#flags-#{flag.id} button[phx-click='toggle']") |> render()

      assert toggle =~ "data-confirm"
      assert toggle =~ "Susu plans"
      assert toggle =~ "on"
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
      assert has_element?(view, "#flags-#{flag.id}", "New Feature")
    end

    test "blank name shows a validation error and creates nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      view
      |> form("#flag-form", %{"key" => "k1", "name" => "", "enabled" => "true"})
      |> render_submit()

      assert has_element?(view, "#flag-form", "Name is required")
      assert {:ok, []} = Emakola.FeatureFlags.list_flags(authorize?: false)
    end

    test "required_plan select offers only the four tiers plus none", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      assert has_element?(view, "#flag-plan option[value='']", "All plans")

      for tier <- ~w(free starter pro enterprise) do
        assert has_element?(view, "#flag-plan option[value='#{tier}']")
      end
    end
  end

  describe "edit" do
    test "updates name and keeps key field disabled", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "edit_me", name: "Before"})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "open_edit_modal", %{"id" => flag.id})
      assert has_element?(view, "#flag-key[disabled]")

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
