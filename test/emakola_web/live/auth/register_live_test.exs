defmodule EmakolaWeb.Auth.RegisterLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  require Ash.Query

  defp unique_email, do: "merchant-#{System.unique_integer([:positive])}@example.com"

  defp all_merchants, do: Ash.read!(Emakola.Accounts.Merchant, authorize?: false)
  defp all_users, do: Ash.read!(Emakola.Accounts.User, authorize?: false)

  defp find_by_email(records, email) do
    Enum.find(records, &(to_string(&1.email) == email))
  end

  describe "registration identity type" do
    test "registering creates an Accounts.Merchant (not an Accounts.User)", %{conn: conn} do
      email = unique_email()

      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      result =
        lv
        |> form("form", user: %{name: "Kwame Asante", email: email, password: "Password123!"})
        |> render_submit()

      # Redirects into the session controller, then on to onboarding
      assert {:error, {:redirect, %{to: to}}} = result
      assert to =~ "/auth/session"
      assert to =~ "redirect_to=%2Fonboarding"

      # A Merchant with this email now exists...
      merchant = find_by_email(all_merchants(), email)
      assert merchant, "expected a Merchant to be created for #{email}"
      assert merchant.name == "Kwame Asante"

      # ...and no legacy User was created for it
      refute find_by_email(all_users(), email)
    end
  end

  describe "registration -> onboarding -> store-gated admin (integration)" do
    test "a registered merchant can complete onboarding and reach the Theme admin page", %{
      conn: conn
    } do
      email = unique_email()

      # 1. Register through the LiveView form (creates a Merchant)
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      lv
      |> form("form", user: %{name: "Ama Mensah", email: email, password: "Password123!"})
      |> render_submit()

      merchant = find_by_email(all_merchants(), email)
      assert merchant

      # 2. Complete onboarding as that merchant (creates Store + StoreMembership)
      token = AshAuthentication.user_to_subject(merchant)

      onboarding_conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, onboarding, _html} = live(onboarding_conn, ~p"/onboarding")

      render_change(onboarding, "update_store_name", %{"store_name" => "Ama Boutique"})
      render_click(onboarding, "next_step")
      render_click(onboarding, "next_step")
      render_click(onboarding, "skip_step")
      render_click(onboarding, "complete")
      assert_redirect(onboarding, "/dashboard")

      store =
        Emakola.Stores.Store
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.name == "Ama Boutique"))

      assert store

      membership =
        Emakola.Accounts.StoreMembership
        |> Ash.Query.filter(merchant_id: merchant.id)
        |> Ash.read!(authorize?: false)

      assert length(membership) == 1
      assert hd(membership).store_id == store.id

      # 3. The store-gated Theme admin page renders for this merchant
      #    (no bounce to /onboarding, no "set up your store first" flash)
      admin_conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:ok, _view, html} = live(admin_conn, ~p"/admin/theme")

      # current_store resolved to the created store (preview renders its name + slug)
      assert html =~ "Choose Your Look"
      assert html =~ store.name
      assert html =~ "/s/#{store.slug}"
    end
  end
end
