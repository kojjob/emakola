defmodule Emakola.Content.Workers.ProductSEOWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  alias Emakola.Catalog.Product
  alias Emakola.Content.RateLimiter
  alias Emakola.Content.Workers.ProductSEOWorker

  setup :verify_on_exit!

  setup do
    {:ok, store: create_store!()}
  end

  test "generates and persists a description for a product missing one", %{store: store} do
    product = create_product!(store, %{description: nil})

    expect(Emakola.Content.GeneratorMock, :generate_product_description, fn _product, _store ->
      {:ok, "A vibrant handwoven basket, perfect for market days."}
    end)

    assert :ok = perform_job(ProductSEOWorker, %{"product_id" => product.id})

    updated = Ash.get!(Product, product.id, authorize?: false)
    assert updated.description =~ "handwoven basket"
    assert updated.description_written_by_ai
  end

  test "skips a product that already has a description (idempotent)", %{store: store} do
    product = create_product!(store, %{description: "Already described"})

    # No mock expectation — the generator must NOT be called.
    assert :ok = perform_job(ProductSEOWorker, %{"product_id" => product.id})
    assert Ash.get!(Product, product.id, authorize?: false).description == "Already described"
  end

  test "cancels (no retry) when the generator is not configured", %{store: store} do
    product = create_product!(store, %{description: nil})

    expect(Emakola.Content.GeneratorMock, :generate_product_description, fn _, _ ->
      {:error, :not_configured}
    end)

    assert {:cancel, _} = perform_job(ProductSEOWorker, %{"product_id" => product.id})
  end

  # A cancelled job never runs again, so a 300-product CSV import used to get
  # 50 descriptions and 250 blanks for ever. The cap resets at UTC midnight;
  # the job waits for it.
  test "snoozes until the daily AI cap resets instead of giving up", %{store: store} do
    product = create_product!(store, %{description: nil})
    for _ <- 1..RateLimiter.default_limit(), do: RateLimiter.check_and_increment(store.id)

    assert {:snooze, seconds} = perform_job(ProductSEOWorker, %{"product_id" => product.id})
    assert seconds in 60..86_460
  end

  test "no-ops when the product no longer exists" do
    assert :ok = perform_job(ProductSEOWorker, %{"product_id" => Ecto.UUID.generate()})
  end
end
