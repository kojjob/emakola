defmodule Emakola.Catalog.SnapVerifiedRevocationTest do
  @moduledoc """
  Any image add/remove/reorder on a snap-verified product must revoke the
  badge (spec: docs/superpowers/specs/2026-08-05-snap-to-shop-design.md).
  Text-only edits (title, alt_text) must never touch it.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    product = create_product!(store, title: "Test Product")
    # Seed the leading image BEFORE verifying — creating it via the real
    # :create action while snap_verified is still false is a no-op for the
    # revocation hook, so it doesn't clobber the badge we're about to set.
    image = create_image!(product, store, %{position: 0})

    {:ok, product} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id,
        authorize?: false
      )
      |> Ash.update()

    %{store: store, product: product, image: image}
  end

  defp snap_verified?(product_id, store_id) do
    Ash.get!(Emakola.Catalog.Product, product_id, tenant: store_id, authorize?: false).snap_verified
  end

  test "destroying an image revokes the badge", %{store: store, product: product, image: image} do
    :ok =
      image
      |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: store.id, authorize?: false)
      |> Ash.destroy()

    refute snap_verified?(product.id, store.id)
  end

  test "adding an image (via the real create action) revokes the badge", %{
    store: store,
    product: product
  } do
    Emakola.Catalog.Image
    |> Ash.Changeset.for_create(
      :create,
      %{
        url: "https://s3.example.com/test/new.jpg",
        content_type: "image/jpeg",
        file_size_bytes: 500_000,
        product_id: product.id,
        store_id: store.id
      },
      tenant: store.id,
      authorize?: false
    )
    |> Ash.create!()

    refute snap_verified?(product.id, store.id)
  end

  test "repositioning an image revokes the badge", %{
    store: store,
    product: product,
    image: image
  } do
    image
    |> Ash.Changeset.for_update(:update, %{position: 1}, tenant: store.id, authorize?: false)
    |> Ash.update!()

    refute snap_verified?(product.id, store.id)
  end

  test "editing alt_text only does NOT revoke", %{store: store, product: product, image: image} do
    image
    |> Ash.Changeset.for_update(:update, %{alt_text: "Updated"},
      tenant: store.id,
      authorize?: false
    )
    |> Ash.update!()

    assert snap_verified?(product.id, store.id)
  end

  test "title edit on the product does NOT revoke", %{store: store, product: product} do
    {:ok, _} =
      product
      |> Ash.Changeset.for_update(:update, %{title: "New name"},
        tenant: store.id,
        authorize?: false
      )
      |> Ash.update()

    assert snap_verified?(product.id, store.id)
  end
end
