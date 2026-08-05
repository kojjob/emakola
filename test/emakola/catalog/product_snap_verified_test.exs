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
end
