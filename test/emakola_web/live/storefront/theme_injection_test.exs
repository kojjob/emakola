defmodule EmakolaWeb.Storefront.ThemeInjectionTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp create_store_with_primary!(primary) do
    store = Factory.create_store!()

    store
    |> Ash.Changeset.for_update(:update, %{
      theme_config: %{"colors" => %{"primary" => primary}}
    })
    |> Ash.update!(authorize?: false)
  end

  defp create_store_with_body_font!(body_font) do
    store = Factory.create_store!()

    store
    |> Ash.Changeset.for_update(:update, %{
      theme_config: %{"fonts" => %{"body" => body_font}}
    })
    |> Ash.update!(authorize?: false)
  end

  describe "layout theme variable injection" do
    test "injects a valid merchant primary color into :root", %{conn: conn} do
      store = create_store_with_primary!("#123456")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "--theme-primary: #123456"
    end

    test "rejects a CSS injection payload and falls back to the default", %{conn: conn} do
      store = create_store_with_primary!("#123456;background:url(//evil)")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "url(//evil)"
      assert html =~ "--theme-primary: #2563EB"
    end
  end

  describe "layout font-family injection" do
    test "rejects a merchant body font CSS injection payload", %{conn: conn} do
      store =
        create_store_with_body_font!("'; background-image: url(//evil2); font-family: '")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "url(//evil2)"
    end
  end

  describe "default renderer theme color injection" do
    test "account page rejects a CSS injection payload in the primary color", %{conn: conn} do
      store = create_store_with_primary!("#B45309;background:url(//evil3)")

      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "ama@example.com",
          name: "Ama Mensah",
          phone: "+233240000000",
          store_id: store.id,
          password: "password123",
          password_confirmation: "password123"
        })
        |> Ash.create!(authorize?: false)

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
      conn = Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      refute html =~ "url(//evil3)"
    end

    test "no default renderer interpolates @theme.colors without safe_css_color" do
      offenders =
        for file <- Path.wildcard("lib/emakola/themes/default_renderers/*.ex"),
            {line, idx} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
            String.contains?(line, "\#{@theme.colors"),
            not String.contains?(line, "safe_css_color"),
            do: "#{file}:#{idx}"

      assert offenders == []
    end
  end
end
