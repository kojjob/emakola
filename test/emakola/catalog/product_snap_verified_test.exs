defmodule Emakola.Catalog.ProductSnapVerifiedTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  test "defaults to false and is settable via :set_snap_verified" do
    store = create_store!()
    product = create_product!(store)
    assert product.snap_verified == false

    {:ok, updated} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id,
        authorize?: false
      )
      |> Ash.update()

    assert updated.snap_verified == true
  end

  # Tripwire: fails the moment someone adds :snap_verified to :create's or
  # :update's accept list. Verified empirically — Ash does not silently drop
  # an unaccepted attribute, it rejects the whole changeset with
  # Ash.Error.Invalid.NoSuchInput, so both actions error rather than
  # succeeding with snap_verified quietly left at its default.
  test "snap_verified cannot be set through :create — badge integrity requires :set_snap_verified" do
    store = create_store!()

    {:error, error} =
      Emakola.Catalog.Product
      |> Ash.Changeset.for_create(
        :create,
        %{title: "Sneaky Product", store_id: store.id, snap_verified: true},
        authorize?: false
      )
      |> Ash.create()

    assert %Ash.Error.Invalid{} = error

    assert Enum.any?(error.errors, fn
             %Ash.Error.Invalid.NoSuchInput{input: :snap_verified} -> true
             _ -> false
           end)
  end

  test "snap_verified cannot be set through :update — badge integrity requires :set_snap_verified" do
    store = create_store!()
    product = create_product!(store)

    {:error, error} =
      product
      |> Ash.Changeset.for_update(:update, %{snap_verified: true}, authorize?: false)
      |> Ash.update()

    assert %Ash.Error.Invalid{} = error

    assert Enum.any?(error.errors, fn
             %Ash.Error.Invalid.NoSuchInput{input: :snap_verified} -> true
             _ -> false
           end)
  end
end
