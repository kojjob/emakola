defmodule EmakolaWeb.Admin.ProductSnapTest do
  # async: false — toggles the :anthropic_api_key application env (same
  # reason seo_dashboard_live_test.exs is async: false). AI is enabled by
  # default for the whole module below (the flow under test needs it); the
  # "AI is disabled" describes override it locally to exercise the gate.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox
  import Emakola.Factory

  # render_async waits 100ms by default. Under a full parallel suite the mocked
  # AI round-trip has missed that with nothing broken; two seconds is still
  # instant when it passes and stops the false reds.
  @async_timeout 2_000

  @small_png Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
             )

  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :anthropic_api_key, "test-key")
    on_exit(fn -> Application.delete_env(:emakola, :anthropic_api_key) end)
  end

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

  defp flagged_payload do
    {:ok,
     %Emakola.AI.Response{
       parsed: %{
         "identified" => true,
         "title" => "Handwoven Stole",
         "description" => "A colourful woven stole.",
         "category" => nil,
         "tags" => ["stole"],
         "alt_text" => "Colourful woven stole",
         "photo_flags" => %{"stock_photo" => true, "watermark" => false, "screenshot" => false}
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

  # Drives a snap-review view to the :review state via the given upload
  # config (:photo_camera / :photo_gallery) and AI payload, mirroring the
  # capture -> reading -> review sequence exercised elsewhere in this file.
  defp drive_to_review(conn, upload_config, payload) do
    stub_storage()
    expect(Emakola.AI.ProviderMock, :complete, fn _req -> payload end)

    {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
    allow_snap_mocks(view)

    upload =
      file_input(view, "#snap-form", upload_config, [
        %{name: "p.png", content: @small_png, type: "image/png"}
      ])

    render_upload(upload, "p.png")
    render_async(view, @async_timeout)

    view
  end

  # :list_by_store sorts inserted_at: :desc, so the first element is newest.
  defp last_product!(store) do
    store.id
    |> Emakola.Catalog.list_products_by_store!(tenant: store.id, authorize?: false)
    |> List.first()
    |> Ash.load!([:images], authorize?: false, tenant: store.id)
  end

  defp images_of(product), do: Enum.sort_by(product.images, & &1.position)

  defp products_of(store) do
    Emakola.Catalog.list_products_by_store!(store.id, tenant: store.id, authorize?: false)
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
      render_async(view, @async_timeout)

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
      render_async(view, @async_timeout)

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
      render_async(view, @async_timeout)

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
      render_async(view, @async_timeout)

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
      render_async(view, @async_timeout)

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
      socket = %{
        assigns: %{
          state: :review,
          uploads: %{photo_camera: %{entries: []}, photo_gallery: %{entries: []}}
        }
      }

      entry = %{done?: true, ref: "stray-ref"}

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_camera, entry, socket)

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_gallery, entry, socket)
    end

    # Closes the gap left by gating render only: `allow_upload` stays
    # registered when AI is off, so a client sending raw upload-channel
    # messages (bypassing the DOM, which the gated render never puts a file
    # input into) could otherwise still reach S3 and burn a rate-limit slot.
    # Exercised as a direct unit call for the same reason as the race-guard
    # test above — the gated render has no file input for a black-box upload
    # helper to target.
    test "handle_progress no-ops when AI is disabled, even for a done entry" do
      socket = %{
        assigns: %{
          ai_enabled: false,
          uploads: %{photo_camera: %{entries: []}, photo_gallery: %{entries: []}}
        }
      }

      entry = %{done?: true, ref: "stray-ref"}

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_camera, entry, socket)

      assert {:noreply, ^socket} =
               EmakolaWeb.Admin.ProductLive.Snap.handle_progress(:photo_gallery, entry, socket)
    end

    test "an invalid file (too large) shows an error the merchant can dismiss", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")

      # allow_upload's max_file_size is 10_000_000 bytes.
      oversized = :binary.copy(<<0>>, 10_000_001)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "big.png", content: oversized, type: "image/png"}
        ])

      # An entry-level error short-circuits render_upload/2 with an
      # {:error, [[ref, reason]]} tuple instead of rendered HTML — the entry
      # (with its error) is still registered on the socket via the preflight
      # ack, so assert against a fresh render/1 instead.
      assert {:error, [[_ref, :too_large]]} = render_upload(upload, "big.png")
      assert render(view) =~ "File is too large"
      assert has_element?(view, "button[phx-click=cancel_snap_entry]", "Remove")
    end

    test "an invalid file (wrong type) shows an error the merchant can dismiss", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "doc.pdf", content: "not an image", type: "application/pdf"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(upload, "doc.pdf")
      assert render(view) =~ "Only image files are accepted"
      assert has_element?(view, "button[phx-click=cancel_snap_entry]", "Remove")
    end

    test "cancel_snap_entry clears a rejected entry so a new file can be picked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "doc.pdf", content: "not an image", type: "application/pdf"}
        ])

      render_upload(upload, "doc.pdf")

      # phx-value-config / phx-value-ref are read straight off the button's
      # DOM attributes — no need to extract the ref manually.
      html = view |> element("button[phx-click=cancel_snap_entry]") |> render_click()

      refute html =~ "Only image files are accepted"

      # The slot is free again — a fresh, valid selection succeeds.
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> ok_payload() end)
      allow_snap_mocks(view)

      second_upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(second_upload, "p.png")
      render_async(view, @async_timeout)

      assert render(view) =~ "Handwoven Stole"
    end

    test "retry_photo clears entries so the same input accepts a new upload afterwards",
         %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, 2, fn _req -> not_identified_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      first_upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(first_upload, "p.png")
      render_async(view, @async_timeout)
      assert :sys.get_state(view.pid).socket.assigns.state == :retry

      view |> element("button[phx-click=retry_photo]") |> render_click()
      assert :sys.get_state(view.pid).socket.assigns.state == :capture

      # Without retry_photo cancelling stray entries first, a second upload
      # through the same :photo_gallery config (max_entries: 1) would hit
      # :too_many_files instead of ever reaching AI generate again.
      second_upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "q.png", content: @small_png, type: "image/png"}
        ])

      render_upload(second_upload, "q.png")
      render_async(view, @async_timeout)

      html = render(view)
      refute html =~ "Only one photo at a time"
      assert :sys.get_state(view.pid).socket.assigns.state == :retry
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
      render_async(view, @async_timeout)

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
      render_async(view, @async_timeout)

      html = view |> element("button[phx-click=retry_photo]") |> render_click()
      assert html =~ ~s(id="snap-form")
    end
  end

  describe "AI provider error" do
    test "→ retry state with a clearer-photo message", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> {:error, :some_reason} end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_gallery, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view, @async_timeout)

      html = render(view)
      assert html =~ "Try a clearer photo"
      assert has_element?(view, "button[phx-click=retry_photo]")

      # This assertion does NOT distinguish handle_async's {:ok, {:error,
      # reason}} clause from its {:exit, reason} clause — both set identical
      # state/retry_message. What actually selects the {:ok, {:error, _}}
      # clause here is the Mox stub above returning {:error, :some_reason} as
      # a normal value (no raise/exit), so the async task completes normally
      # instead of crashing. This line just confirms the resulting state.
      assert :sys.get_state(view.pid).socket.assigns.state == :retry
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

  describe "review card submit" do
    test "publish with camera source + clean flags → active product with badge", %{
      conn: conn,
      store: store
    } do
      view = drive_to_review(conn, :photo_camera, ok_payload())

      # Structural check on the two submit buttons — the test drives the
      # event via render_submit/2's injected value map, which would stay
      # green even if the buttons had the wrong name/value wiring.
      assert has_element?(
               view,
               ~s{#snap-review-form button[type=submit][name=action][value=publish]}
             )

      assert has_element?(
               view,
               ~s{#snap-review-form button[type=submit][name=action][value=draft]}
             )

      result =
        view
        |> form("#snap-review-form", %{"price" => "180.50"})
        |> render_submit(%{"action" => "publish"})

      product = last_product!(store)
      assert {:error, {:live_redirect, %{to: to}}} = result
      assert to == "/admin/products/#{product.id}/edit"
      assert product.snap_verified
      assert product.status == :active

      [variant] = Ash.load!(product, [:variants], authorize?: false, tenant: store.id).variants
      assert variant.price == 18_050

      image = hd(images_of(product))
      assert image.position == 0
      assert image.alt_text == "Colourful woven stole"
      assert image.url =~ "/snap/"
    end

    test "gallery source → no badge", %{conn: conn, store: store} do
      view = drive_to_review(conn, :photo_gallery, ok_payload())

      view
      |> form("#snap-review-form", %{"price" => "180.00"})
      |> render_submit(%{"action" => "publish"})

      product = last_product!(store)
      refute product.snap_verified
      assert product.status == :active
    end

    test "flagged photo → no badge even from camera", %{conn: conn, store: store} do
      view = drive_to_review(conn, :photo_camera, flagged_payload())

      view
      |> form("#snap-review-form", %{"price" => "180.00"})
      |> render_submit(%{"action" => "publish"})

      product = last_product!(store)
      refute product.snap_verified
      assert product.status == :active
    end

    test "publish without price → error, no product created", %{conn: conn, store: store} do
      view = drive_to_review(conn, :photo_camera, ok_payload())

      view
      |> form("#snap-review-form", %{"price" => ""})
      |> render_submit(%{"action" => "publish"})

      assert render(view) =~ "Add your price"
      assert [] == products_of(store)
    end

    test "save draft → status draft", %{conn: conn, store: store} do
      view = drive_to_review(conn, :photo_camera, ok_payload())

      view
      |> form("#snap-review-form", %{"price" => "180.00"})
      |> render_submit(%{"action" => "draft"})

      product = last_product!(store)
      assert product.status == :draft
    end

    # Task 5 rider: proves submitted form params drive the created product,
    # not the stale `ai` assign — a price-only edit wouldn't catch a bug
    # where the title fell back to @ai.title instead of params["title"].
    test "an edited title in the submitted form overrides the AI's title", %{
      conn: conn,
      store: store
    } do
      view = drive_to_review(conn, :photo_camera, ok_payload())

      view
      |> form("#snap-review-form", %{"price" => "180.00", "title" => "Merchant Edited Title"})
      |> render_submit(%{"action" => "publish"})

      product = last_product!(store)
      assert product.title == "Merchant Edited Title"
      refute product.title == "Handwoven Stole"
    end

    # Forces a failure at the image-attach step (Image's url has a 2048-char
    # max_length) after the product and variant have already been written,
    # to prove the sequence is transactional — a failed step must not leave
    # an orphaned draft product behind.
    test "a failed step leaves no product behind", %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _binary, _path, _opts ->
        {:ok, "https://s3.example.com/" <> String.duplicate("x", 2100) <> ".png"}
      end)

      expect(Emakola.AI.ProviderMock, :complete, fn _req -> ok_payload() end)

      {:ok, view, _html} = live(conn, ~p"/admin/products/snap")
      allow_snap_mocks(view)

      upload =
        file_input(view, "#snap-form", :photo_camera, [
          %{name: "p.png", content: @small_png, type: "image/png"}
        ])

      render_upload(upload, "p.png")
      render_async(view, @async_timeout)

      view
      |> form("#snap-review-form", %{"price" => "180.00"})
      |> render_submit(%{"action" => "publish"})

      assert [] == products_of(store)
    end
  end

  describe "save_snap_product guard" do
    # Not DOM-reachable — the submit button only exists in review_state's
    # markup — but a directly-pushed event before AI has completed (ai is
    # nil pre-:review) would otherwise crash on @ai.title/@ai.description
    # inside create_snap_product. Exercised as a direct unit call, same
    # rationale as the handle_progress race-guard test above.
    #
    # This alone doesn't prove the :review clause is the one doing real work
    # (a bug that dropped the `%{assigns: %{state: :review}}` match and left
    # an unconditional no-op behind would pass this test too). The positive
    # side is "publish without price → error, no product created" above,
    # which drives a real socket to :review via the DOM and shows
    # save_snap_product reaching the price-parse branch — a bare fake socket
    # can't stand in for that positive check here because Phoenix.Component's
    # `assign/2` requires a genuine `%Phoenix.LiveView.Socket{}` (or an
    # assigns map carrying `:__changed__`), which a hand-built map like
    # `socket` below doesn't have.
    test "no-ops for every non-:review state" do
      for state <- [:capture, :reading, :retry] do
        socket = %{assigns: %{state: state}}

        assert {:noreply, ^socket} =
                 EmakolaWeb.Admin.ProductLive.Snap.handle_event("save_snap_product", %{}, socket)
      end
    end
  end

  describe "fake-photo warning" do
    test "a flagged photo shows the amber warning on the review card", %{conn: conn} do
      view = drive_to_review(conn, :photo_camera, flagged_payload())

      assert has_element?(view, "#snap-photo-warning", "Buyers trust real photos")
    end

    test "a clean photo does not show the warning", %{conn: conn} do
      view = drive_to_review(conn, :photo_camera, ok_payload())

      refute has_element?(view, "#snap-photo-warning")
    end
  end

  describe "entry point" do
    test "products index links to the snap page when AI is enabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")
      assert has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end

  describe "entry point when AI is disabled" do
    setup do
      Application.delete_env(:emakola, :anthropic_api_key)
    end

    test "products index does not link to the snap page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")
      refute has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end

  describe "direct route /admin/products/snap when AI is disabled" do
    setup do
      Application.delete_env(:emakola, :anthropic_api_key)
    end

    test "renders the gated banner instead of the capture form, no upload inputs in the DOM",
         %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/products/snap")

      assert html =~ "switched on yet"
      refute has_element?(view, "#snap-form")
      refute has_element?(view, "input[type=file]")
    end
  end

  describe "merchant without a store" do
    test "redirects to the dashboard instead of crashing", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> get(~p"/admin/products/snap")

      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Create your store first"
    end
  end
end
