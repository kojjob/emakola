defmodule Emakola.Catalog.Changes.BackfillDescriptionTest do
  @moduledoc """
  A product saved without a description gets one written by the AI backfill
  without the merchant asking. The SEO dashboard button is the only other
  trigger, and a merchant who cannot read well never opens a page called SEO.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Content.Workers.ProductSEOWorker

  setup do
    {:ok, store: create_store!()}
  end

  test "creating a product with no description queues the AI backfill", %{store: store} do
    product = create_product!(store, title: "Oraimo FreePods 3 earbuds")

    assert_enqueued(worker: ProductSEOWorker, args: %{product_id: product.id})
  end

  test "a blank description counts as missing", %{store: store} do
    product = create_product!(store, title: "Tote bag", description: "   ")

    assert_enqueued(worker: ProductSEOWorker, args: %{product_id: product.id})
  end

  test "a product the merchant described is left alone", %{store: store} do
    product =
      create_product!(store, title: "Tote bag", description: "Canvas tote, 40cm, zip top.")

    refute_enqueued(worker: ProductSEOWorker, args: %{product_id: product.id})
  end
end
