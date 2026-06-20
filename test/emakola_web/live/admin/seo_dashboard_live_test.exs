defmodule EmakolaWeb.Admin.SEODashboardLiveTest do
  # async: false — toggles the :anthropic_api_key application env.
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Content.Workers.{ImageAltTextWorker, ProductSEOWorker}

  setup %{conn: conn} do
    Application.put_env(:emakola, :anthropic_api_key, "test-key")
    on_exit(fn -> Application.delete_env(:emakola, :anthropic_api_key) end)

    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "shows the count of products missing descriptions", %{conn: conn, store: store} do
    create_product!(store, %{description: nil})

    {:ok, _view, html} = live(conn, ~p"/admin/seo")

    assert html =~ "Products without descriptions"
    assert html =~ "Generate descriptions"
  end

  test "queues ProductSEOWorker jobs for products missing descriptions", %{
    conn: conn,
    store: store
  } do
    create_product!(store, %{description: nil})

    {:ok, view, _html} = live(conn, ~p"/admin/seo")
    view |> element("button[phx-click=generate_descriptions]") |> render_click()

    assert_enqueued(worker: ProductSEOWorker)
  end

  test "queues ImageAltTextWorker jobs for images missing alt text", %{conn: conn, store: store} do
    product = create_product!(store)
    create_image!(product, store, %{alt_text: nil})

    {:ok, view, _html} = live(conn, ~p"/admin/seo")
    view |> element("button[phx-click=generate_alt_text]") |> render_click()

    assert_enqueued(worker: ImageAltTextWorker)
  end

  test "shows a not-configured notice and no buttons when AI is off", %{conn: conn, store: store} do
    Application.delete_env(:emakola, :anthropic_api_key)
    create_product!(store, %{description: nil})

    {:ok, _view, html} = live(conn, ~p"/admin/seo")

    # Apostrophe in "isn't" is HTML-escaped, so match an apostrophe-free fragment.
    assert html =~ "switched on yet"
    refute html =~ "phx-click=\"generate_descriptions\""
  end
end
