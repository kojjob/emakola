defmodule EmakolaWeb.OnboardingLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp auth_conn(conn, user) do
    token = AshAuthentication.user_to_subject(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "mount" do
    test "renders step 1 for unauthenticated user", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Create Your Organisation"
    end

    test "redirects to dashboard when user already has an org", %{conn: conn} do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)

      conn = auth_conn(conn, user)

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, "/onboarding")
    end

    test "renders step 1 for authenticated user without org", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Create Your Organisation"
    end
  end

  describe "step validation" do
    test "blocks step 1 advance with blank org name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      html = render_click(view, "next_step")
      assert html =~ "Please enter an organisation name"
    end

    test "advances from step 1 with valid org name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      html = render_click(view, "next_step")
      assert html =~ "Invite Your Team"
    end

    test "rejects invalid email in step 2", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")

      html = render_submit(view, "add_invite", %{"email" => "not-an-email"})
      assert html =~ "valid email"
    end

    test "accepts valid email in step 2", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")

      html = render_submit(view, "add_invite", %{"email" => "teammate@example.com"})
      assert html =~ "teammate@example.com"
    end
  end

  describe "complete" do
    # TODO: Rewrite for Emakola store creation flow (currently references FounderPad AI.Agent)
    @tag :skip
    test "creates org and membership on complete", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1: org name
      render_change(view, "update_org_name", %{"org_name" => "My Startup"})
      render_click(view, "next_step")

      # Step 2: skip invites
      render_click(view, "next_step")

      # Step 3: select template
      render_click(view, "select_template", %{"template" => "research"})
      render_click(view, "next_step")

      # Step 4: complete
      render_click(view, "complete")

      # Verify org created
      orgs = Emakola.Accounts.Organisation |> Ash.read!()
      assert Enum.any?(orgs, &(&1.name == "My Startup"))

      # Verify membership created
      memberships =
        Emakola.Accounts.Membership
        |> Ash.read!()
        |> Enum.filter(&(&1.user_id == user.id))

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
    end

    test "shows error when completing without org name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      html = render_click(view, "next_step")
      assert html =~ "Please enter an organisation name"
    end
  end
end
