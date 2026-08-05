defmodule EmakolaWeb.Admin.ProductSnapTest do
  # async: false — the entry-point tests toggle the :anthropic_api_key
  # application env (same reason seo_dashboard_live_test.exs is async: false).
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox
  import Emakola.Factory

  @small_png Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
             )

  setup :verify_on_exit!

  setup %{conn: conn} do
    {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp ok_payload do
    {:ok,
     %Emakola.AI.Response{
       parsed: %{
         "identified" => true,
         "title" => "Handwoven Stole",
         "description" => "A colourful woven stole.",
         "category" => nil,
         "tags" => ["stole"],
         "alt_text" => "Colourful woven stole",
         "photo_flags" => %{"stock_photo" => false, "watermark" => false, "screenshot" => false}
       },
       model: "claude-sonnet-5",
       usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
     }}
  end

  defp not_identified_payload do
    {:ok,
     %Emakola.AI.Response{
       parsed: %{
         "identified" => false,
         "title" => "",
         "description" => "",
         "category" => nil,
         "tags" => [],
         "alt_text" => "",
         "photo_flags" => %{"stock_photo" => false, "watermark" => false, "screenshot" => false}
       },
       model: "claude-sonnet-5",
       usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
     }}
  end

  defp stub_storage do
    stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "https://s3.example.com/#{path}"}
    end)
  end

  defp allow_snap_mocks(view) do
    Mox.allow(Emakola.StorageMock, self(), view.pid)
    Mox.allow(Emakola.AI.ProviderMock, self(), view.pid)
  end

  describe "capture state" do
    test "renders camera and gallery overlay inputs, not sr-only", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products/snap")

      assert html =~ ~s(id="snap-form")
      assert html =~ ~s(capture="environment")
      refute html =~ "sr-only"
      assert html =~ "opacity-0"
      assert html =~ "Take a photo"
      assert html =~ "Choose from gallery"
    end
  end

  describe "upload → reading → review" do
    test "snap → reading → review card shows AI fields and empty price", %{conn: conn} do
      stub_storage()

      expect(Emakola.AI.ProviderMock, :complete, fn req ->
        assert req.feature == :snap_to_shop
        ok_payload()
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      html = render(view)
      assert html =~ "Handwoven Stole"
      assert html =~ "snap-price"
      refute html =~ "Reading"
    end

    test "a gallery upload records :gallery as the source", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> ok_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      assert :sys.get_state(view.pid).socket.assigns.source == :gallery
    end

    test "a camera upload records :camera as the source", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> ok_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_camera, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      assert :sys.get_state(view.pid).socket.assigns.source == :camera
    end

    test "an exact category name match resolves category_id; a clean photo_flags map sets flags_clean?",
         %{conn: conn, store: store} do
      category = create_category!(store, %{name: "Textiles"})
      stub_storage()

      expect(Emakola.AI.ProviderMock, :complete, fn _req ->
        {:ok,
         %Emakola.AI.Response{
           parsed: %{
             "identified" => true,
             "title" => "Kente",
             "description" => "Woven cloth.",
             "category" => "Textiles",
             "tags" => [],
             "alt_text" => "Kente cloth",
             "photo_flags" => %{
               "stock_photo" => false,
               "watermark" => false,
               "screenshot" => false
             }
           },
           model: "claude-sonnet-5",
           usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.category_id == category.id
      assert assigns.flags_clean? == true
    end

    test "a dirty photo_flags map fails closed: flags_clean? is false", %{conn: conn} do
      stub_storage()

      expect(Emakola.AI.ProviderMock, :complete, fn _req ->
        {:ok,
         %Emakola.AI.Response{
           parsed: %{
             "identified" => true,
             "title" => "Kente",
             "description" => "Woven cloth.",
             "category" => nil,
             "tags" => [],
             "alt_text" => "Kente cloth",
             "photo_flags" => %{
               "stock_photo" => true,
               "watermark" => false,
               "screenshot" => false
             }
           },
           model: "claude-sonnet-5",
           usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      assert :sys.get_state(view.pid).socket.assigns.flags_clean? == false
    end

    # A merchant tapping both overlay inputs in the same instant can land two
    # `handle_progress(done?: true)` messages in the LiveView process's
    # mailbox before the first is processed. Erlang delivers them one at a
    # time, so by the time the second is handled, the first has already
    # moved `state` off `:capture` — this asserts the guard clause that
    # keeps that second message from restarting the read. Exercised as a
    # direct unit call (not through Phoenix.LiveViewTest.render_upload/2):
    # once state leaves :capture, the capture markup — and both file inputs
    # with it — is removed from the render tree, so the black-box upload
    # helpers can no longer target the "other" input to reproduce the race.
    test "handle_progress ignores a progress event once the flow has moved past :capture" do
      socket = %{assigns: %{state: :review}}
      entry = %{done?: true}

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_camera, entry, socket)

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_gallery, entry, socket)
    end
  end

  describe "AI says not identified" do
    test "→ retry state with a clearer-photo message", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> not_identified_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      html = render(view)
      assert html =~ "Try a clearer photo"
      assert has_element?(view, "button[phx-click=retry_photo]")
    end

    test "retry_photo resets the flow back to the capture state", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> not_identified_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view)

      html = view |> element("button[phx-click=retry_photo]") |> render_click()
      assert html =~ ~s(id="snap-form")
    end
  end

  describe "rate limit" do
    test "exceeded → retry state with the daily-limit message, no AI call", %{
      conn: conn,
      store: store
    } do
      stub_storage()
      limit = Emakola.Content.RateLimiter.default_limit()
      for _ <- 1..limit, do: Emakola.Content.RateLimiter.check_and_increment(store.id)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")

      html = render(view)
      assert html =~ "Daily AI limit reached"
    end
  end

  describe "entry point" do
    setup do
      Application.put_env(:emakola, :anthropic_api_key, "test-key")
      on_exit(fn -> Application.delete_env(:emakola, :anthropic_api_key) end)
    end

    test "products index links to the snap page when AI is enabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")
      assert has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end

  describe "entry point when AI is disabled" do
    test "products index does not link to the snap page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")
      refute has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end
end
