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
end
