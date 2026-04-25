defmodule Emakola.Shipping.DeliveryZoneTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  # -- Creation ---------------------------------------------------------------

  describe "create" do
    test "creates a delivery zone with valid attributes", %{store: store} do
      zone = create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

      assert zone.id
      assert zone.name == "Greater Accra"
      assert zone.fee == 1500
      assert zone.store_id == store.id
      assert zone.estimated_days == 1
      assert zone.active == true
    end

    test "creates zone with custom estimated_days", %{store: store} do
      zone = create_delivery_zone!(store, name: "Northern", fee: 3500, estimated_days: 5)

      assert zone.estimated_days == 5
    end

    test "rejects missing name", %{store: store} do
      assert {:error, _} =
               Emakola.Shipping.DeliveryZone
               |> Ash.Changeset.for_create(:create, %{store_id: store.id, fee: 1500})
               |> Ash.create(authorize?: false)
    end

    test "rejects missing fee", %{store: store} do
      assert {:error, _} =
               Emakola.Shipping.DeliveryZone
               |> Ash.Changeset.for_create(:create, %{store_id: store.id, name: "Test"})
               |> Ash.create(authorize?: false)
    end

    test "rejects missing store_id" do
      assert {:error, _} =
               Emakola.Shipping.DeliveryZone
               |> Ash.Changeset.for_create(:create, %{name: "Test", fee: 1500})
               |> Ash.create(authorize?: false)
    end

    test "fee must be >= 0", %{store: store} do
      assert {:error, _} =
               Emakola.Shipping.DeliveryZone
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 name: "Test",
                 fee: -100
               })
               |> Ash.create(authorize?: false)
    end

    test "name is unique per store", %{store: store} do
      create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

      assert {:error, _} =
               Emakola.Shipping.DeliveryZone
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 name: "Greater Accra",
                 fee: 2000
               })
               |> Ash.create(authorize?: false)
    end

    test "same name allowed in different stores", %{store: store} do
      store2 = create_store!()
      create_delivery_zone!(store, name: "Greater Accra", fee: 1500)
      zone2 = create_delivery_zone!(store2, name: "Greater Accra", fee: 2000)

      assert zone2.name == "Greater Accra"
    end
  end

  # -- List by store ----------------------------------------------------------

  describe "list_by_store" do
    test "returns zones for the given store", %{store: store} do
      create_delivery_zone!(store, name: "Greater Accra", fee: 1500)
      create_delivery_zone!(store, name: "Ashanti", fee: 2500)

      {:ok, zones} =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert length(zones) == 2
      names = Enum.map(zones, & &1.name) |> Enum.sort()
      assert names == ["Ashanti", "Greater Accra"]
    end

    test "does not return zones from other stores", %{store: store} do
      store2 = create_store!()
      create_delivery_zone!(store, name: "Greater Accra", fee: 1500)
      create_delivery_zone!(store2, name: "Lagos", fee: 3000)

      {:ok, zones} =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert length(zones) == 1
      assert hd(zones).name == "Greater Accra"
    end
  end

  # -- Update -----------------------------------------------------------------

  describe "update" do
    test "updates zone attributes", %{store: store} do
      zone = create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

      {:ok, updated} =
        zone
        |> Ash.Changeset.for_update(:update, %{fee: 2000, estimated_days: 2})
        |> Ash.update(authorize?: false)

      assert updated.fee == 2000
      assert updated.estimated_days == 2
    end

    test "can toggle active status", %{store: store} do
      zone = create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

      {:ok, updated} =
        zone
        |> Ash.Changeset.for_update(:update, %{active: false})
        |> Ash.update(authorize?: false)

      assert updated.active == false
    end
  end

  # -- Destroy ----------------------------------------------------------------

  describe "destroy" do
    test "deletes a delivery zone", %{store: store} do
      zone = create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

      assert :ok = Ash.destroy!(zone)

      {:ok, zones} =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert zones == []
    end
  end

  # -- Multi-tenant isolation -------------------------------------------------

  describe "multi-tenant isolation" do
    test "zones are isolated per store", %{store: store} do
      store2 = create_store!()

      create_delivery_zone!(store, name: "Zone A", fee: 1000)
      create_delivery_zone!(store, name: "Zone B", fee: 2000)
      create_delivery_zone!(store2, name: "Zone C", fee: 3000)

      {:ok, store1_zones} =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      {:ok, store2_zones} =
        Emakola.Shipping.DeliveryZone
        |> Ash.Query.filter(store_id == ^store2.id)
        |> Ash.read(authorize?: false)

      assert length(store1_zones) == 2
      assert length(store2_zones) == 1
    end
  end
end
