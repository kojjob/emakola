defmodule EmakolaWeb.Admin.ProductLive.AddProductsFillTest do
  @moduledoc """
  "Fill it in" is the AI snap page folded into a card: the AI reads the
  photo into the card's name, description and category, the amber line says
  so, and a camera photo the AI found clean still earns the Real-photo
  badge when the card is published.
  """
  # async: false — toggles the :anthropic_api_key application env.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

  # render_async waits 100ms by default; under a full parallel suite the
  # mocked AI round-trip has missed that with nothing broken.
  @async_timeout 2_000

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :anthropic_api_key, "test-key")
    on_exit(fn -> Application.delete_env(:emakola, :anthropic_api_key) end)
  end

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  describe "fill" do
    test "reads the photo into the card and says Makola wrote it", %{conn: conn, store: store} do
      category = Emakola.Factory.create_category!(store, %{name: "Beauty"})
      stub_storage()

      expect(Emakola.AI.ProviderMock, :complete, fn req ->
        assert req.feature == :snap_to_shop
        ok_payload(category: "Beauty")
      end)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :photos, "gloss.png")

      view |> element("#fill-photos-#{ref}") |> render_click()
      render_async(view, @async_timeout)

      assert has_element?(view, ~s{#card-name-photos-#{ref}[value="Handwoven Stole"]})
      assert render(view) =~ "Makola wrote this"
      assert has_element?(view, "#more-photos-#{ref}", "Beauty")
      refute has_element?(view, "#fill-photos-#{ref}")

      view |> element("#more-photos-#{ref}") |> render_click()
      assert render(view) =~ "A colourful woven stole."
      assert has_element?(view, ~s{button[data-category="#{category.id}"][data-on]})
    end

    test "a name the merchant typed first is kept", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> ok_payload() end)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :photos, "gloss.png")
      set_card(view, ref, "name", "My gloss")

      view |> element("#fill-photos-#{ref}") |> render_click()
      render_async(view, @async_timeout)

      assert has_element?(view, ~s{#card-name-photos-#{ref}[value="My gloss"]})
      view |> element("#more-photos-#{ref}") |> render_click()
      assert render(view) =~ "A colourful woven stole."
    end

    test "a photo the AI cannot read leaves the card alone and says so", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> not_identified_payload() end)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :photos, "blur.png")

      view |> element("#fill-photos-#{ref}") |> render_click()
      html = render_async(view, @async_timeout)

      assert html =~ "Try a clearer photo"
      assert has_element?(view, ~s{#card-name-photos-#{ref}[value=""]})
      assert has_element?(view, "#fill-photos-#{ref}")
    end

    test "a camera photo of a screen says the badge is lost and how to earn it", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> screen_photo_payload() end)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :camera, "screen.png")

      view |> element("#fill-camera-#{ref}") |> render_click()
      html = render_async(view, @async_timeout)

      assert html =~ "No Real photo badge. Snap the item itself."
    end

    test "a gallery photo says nothing about the badge", %{conn: conn} do
      stub_storage()
      expect(Emakola.AI.ProviderMock, :complete, fn _req -> screen_photo_payload() end)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :photos, "screen.png")

      view |> element("#fill-photos-#{ref}") |> render_click()
      html = render_async(view, @async_timeout)

      refute html =~ "No Real photo badge"
    end

    test "past the daily AI limit the page says so and no call is made", %{
      conn: conn,
      store: store
    } do
      stub_storage()
      limit = Emakola.Content.RateLimiter.default_limit()
      for _ <- 1..limit, do: Emakola.Content.RateLimiter.check_and_increment(store.id)

      {:ok, view, _html} = live(conn, "/admin/products/new")
      allow_mocks(view)
      ref = upload_photo(view, :photos, "p.png")

      html = view |> element("#fill-photos-#{ref}") |> render_click()

      assert html =~ "Daily AI limit reached"
    end
  end

  describe "without an AI key" do
    setup do
      Application.delete_env(:emakola, :anthropic_api_key)
    end

    test "there is no pill to tap", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/new")
      ref = upload_photo(view, :photos, "p.png")

      refute has_element?(view, "#fill-photos-#{ref}")
    end
  end

  describe "publish after a fill" do
    test "a camera photo the AI found clean earns the badge", %{conn: conn, store: store} do
      product = fill_and_publish(conn, store, :camera, ok_payload())

      assert product.snap_verified
      assert product.description == "A colourful woven stole."
      assert product.description_written_by_ai
      assert [%{alt_text: "Colourful woven stole"}] = product.images
    end

    test "a gallery photo earns no badge", %{conn: conn, store: store} do
      product = fill_and_publish(conn, store, :photos, ok_payload())

      refute product.snap_verified
    end

    test "a flagged photo earns no badge even from the camera", %{conn: conn, store: store} do
      product = fill_and_publish(conn, store, :camera, flagged_payload())

      refute product.snap_verified
    end

    test "a camera photo of a screen earns no badge", %{conn: conn, store: store} do
      product = fill_and_publish(conn, store, :camera, screen_photo_payload())

      refute product.snap_verified
    end

    test "a description the merchant changes is theirs", %{conn: conn, store: store} do
      product =
        fill_and_publish(conn, store, :photos, ok_payload(), fn view, ref ->
          set_card(view, ref, "description", "My own words.")
        end)

      assert product.description == "My own words."
      refute product.description_written_by_ai
    end
  end

  # ── helpers ──

  defp fill_and_publish(conn, store, upload, payload, before_publish \\ fn _view, _ref -> :ok end) do
    stub_storage()
    expect(Emakola.AI.ProviderMock, :complete, fn _req -> payload end)

    {:ok, view, _html} = live(conn, "/admin/products/new")
    allow_mocks(view)
    ref = upload_photo(view, upload, "stole.png")

    view |> element("#fill-#{upload}-#{ref}") |> render_click()
    render_async(view, @async_timeout)

    set_card(view, ref, "price", "120", to_string(upload))
    before_publish.(view, ref)
    view |> element("#add-products-form") |> render_submit()

    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store.id and title == "Handwoven Stole")
    |> Ash.read_one!(authorize?: false, load: [:images])
  end

  defp upload_photo(view, upload, name) do
    photo =
      file_input(view, "#add-products-form", upload, [
        %{name: name, content: @png, type: "image/png"}
      ])

    render_upload(photo, name)

    [[_, ref]] = Regex.scan(~r/id="card-#{upload}-([^"]+)"/, render(view))
    ref
  end

  defp set_card(view, ref, field, value, upload \\ "photos") do
    render_hook(view, "set_card", %{
      "upload" => upload,
      "ref" => ref,
      "field" => field,
      "value" => value
    })
  end

  defp allow_mocks(view) do
    Mox.allow(Emakola.StorageMock, self(), view.pid)
    Mox.allow(Emakola.AI.ProviderMock, self(), view.pid)
  end

  defp stub_storage do
    stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "https://s3.example.com/#{path}"}
    end)
  end

  defp ok_payload(opts \\ []) do
    response(%{
      "identified" => true,
      "title" => "Handwoven Stole",
      "description" => "A colourful woven stole.",
      "category" => Keyword.get(opts, :category),
      "tags" => ["stole"],
      "alt_text" => "Colourful woven stole",
      "photo_flags" => %{
        "stock_photo" => false,
        "watermark" => false,
        "screenshot" => false,
        "screen_photo" => false
      }
    })
  end

  defp flagged_payload do
    response(%{
      "identified" => true,
      "title" => "Handwoven Stole",
      "description" => "A colourful woven stole.",
      "category" => nil,
      "tags" => ["stole"],
      "alt_text" => "Colourful woven stole",
      "photo_flags" => %{
        "stock_photo" => true,
        "watermark" => false,
        "screenshot" => false,
        "screen_photo" => false
      }
    })
  end

  # Every other flag is clear: only the re-photographed display gives it away.
  defp screen_photo_payload do
    response(%{
      "identified" => true,
      "title" => "Handwoven Stole",
      "description" => "A colourful woven stole.",
      "category" => nil,
      "tags" => ["stole"],
      "alt_text" => "Colourful woven stole",
      "photo_flags" => %{
        "stock_photo" => false,
        "watermark" => false,
        "screenshot" => false,
        "screen_photo" => true
      }
    })
  end

  defp not_identified_payload do
    response(%{
      "identified" => false,
      "title" => "",
      "description" => "",
      "category" => nil,
      "tags" => [],
      "alt_text" => "",
      "photo_flags" => %{
        "stock_photo" => false,
        "watermark" => false,
        "screenshot" => false,
        "screen_photo" => false
      }
    })
  end

  defp response(parsed) do
    {:ok,
     %Emakola.AI.Response{
       parsed: parsed,
       model: "claude-sonnet-5",
       usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
     }}
  end
end
