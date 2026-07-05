defmodule Emakola.Content.Workers.ImageAltTextWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  alias Emakola.Catalog.Image
  alias Emakola.Content.RateLimiter
  alias Emakola.Content.Workers.ImageAltTextWorker

  setup :verify_on_exit!

  setup do
    store = create_store!()
    product = create_product!(store)
    {:ok, store: store, product: product}
  end

  test "generates and persists alt text for an image missing one", ctx do
    image = create_image!(ctx.product, ctx.store, %{alt_text: nil})

    expect(Emakola.Content.GeneratorMock, :generate_image_alt_text, fn _url ->
      {:ok, "Handwoven basket in gold and green"}
    end)

    assert :ok = perform_job(ImageAltTextWorker, %{"image_id" => image.id})
    assert Ash.get!(Image, image.id, authorize?: false).alt_text =~ "basket"
  end

  test "skips an image that already has alt text (idempotent)", ctx do
    image = create_image!(ctx.product, ctx.store, %{alt_text: "Existing alt"})

    assert :ok = perform_job(ImageAltTextWorker, %{"image_id" => image.id})
    assert Ash.get!(Image, image.id, authorize?: false).alt_text == "Existing alt"
  end

  test "cancels when the generator is not configured", ctx do
    image = create_image!(ctx.product, ctx.store, %{alt_text: nil})

    expect(Emakola.Content.GeneratorMock, :generate_image_alt_text, fn _ ->
      {:error, :not_configured}
    end)

    assert {:cancel, _} = perform_job(ImageAltTextWorker, %{"image_id" => image.id})
  end

  test "cancels when the store hit its daily AI limit", ctx do
    image = create_image!(ctx.product, ctx.store, %{alt_text: nil})
    for _ <- 1..RateLimiter.default_limit(), do: RateLimiter.check_and_increment(ctx.store.id)

    assert {:cancel, _} = perform_job(ImageAltTextWorker, %{"image_id" => image.id})
  end

  test "no-ops when the image no longer exists" do
    assert :ok = perform_job(ImageAltTextWorker, %{"image_id" => Ecto.UUID.generate()})
  end
end
