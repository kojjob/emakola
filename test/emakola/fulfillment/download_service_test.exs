defmodule Emakola.Fulfillment.DownloadServiceTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Mox

  setup :verify_on_exit!

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant
  alias Emakola.Fulfillment.DownloadService

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp issue_grant!(overrides \\ %{}) do
    store = digital_store!()
    product = create_product!(store, product_type: :digital_download)
    variant = create_variant!(product, store)
    customer = create_customer!(store)
    order = create_order!(store, customer_id: customer.id)

    line_item =
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    file =
      DigitalFile
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        file_name: "asset.zip",
        storage_key: "stores/#{store.id}/files/asset-#{System.unique_integer([:positive])}.zip",
        content_type: "application/zip",
        byte_size: 1_000_000
      })
      |> Ash.create!(authorize?: false)

    DownloadGrant
    |> Ash.Changeset.for_create(
      :issue,
      Map.merge(
        %{
          store_id: store.id,
          order_id: order.id,
          line_item_id: line_item.id,
          customer_id: customer.id,
          digital_file_id: file.id
        },
        Map.new(overrides)
      )
    )
    |> Ash.create!(authorize?: false)
    |> Ash.load!(:digital_file, authorize?: false)
  end

  describe "issue_url/1 — happy path" do
    test "returns a presigned URL when grant is valid" do
      grant = issue_grant!()

      expect(Emakola.StorageMock, :presigned_url, fn path, _opts ->
        assert path == grant.digital_file.storage_key
        {:ok, "https://cdn.example/sig?token=abc"}
      end)

      assert {:ok, "https://cdn.example/sig?token=abc"} = DownloadService.issue_url(grant)
    end

    test "increments downloaded_count on success" do
      grant = issue_grant!()

      stub(Emakola.StorageMock, :presigned_url, fn _path, _opts ->
        {:ok, "https://cdn.example/sig?token=abc"}
      end)

      assert {:ok, _url} = DownloadService.issue_url(grant)

      reloaded = Ash.get!(DownloadGrant, grant.id, authorize?: false)
      assert reloaded.downloaded_count == 1
    end

    test "does not increment downloaded_count on storage failure" do
      grant = issue_grant!()

      expect(Emakola.StorageMock, :presigned_url, fn _path, _opts ->
        {:error, :s3_unavailable}
      end)

      assert {:error, {:storage, :s3_unavailable}} = DownloadService.issue_url(grant)

      reloaded = Ash.get!(DownloadGrant, grant.id, authorize?: false)
      assert reloaded.downloaded_count == 0
    end
  end

  describe "issue_url/1 — expiry" do
    test "rejects with :expired when expires_at is in the past" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      grant = issue_grant!(%{expires_at: past})

      assert {:error, :expired} = DownloadService.issue_url(grant)
    end

    test "accepts when expires_at is in the future" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      grant = issue_grant!(%{expires_at: future})

      stub(Emakola.StorageMock, :presigned_url, fn _, _ -> {:ok, "https://cdn/sig"} end)
      assert {:ok, _} = DownloadService.issue_url(grant)
    end

    test "accepts when expires_at is nil (never expires)" do
      grant = issue_grant!()
      assert grant.expires_at == nil

      stub(Emakola.StorageMock, :presigned_url, fn _, _ -> {:ok, "https://cdn/sig"} end)
      assert {:ok, _} = DownloadService.issue_url(grant)
    end
  end

  describe "issue_url/1 — download limit" do
    test "rejects with :limit_reached when downloaded_count >= download_limit" do
      grant = issue_grant!(%{download_limit: 2})

      stub(Emakola.StorageMock, :presigned_url, fn _, _ -> {:ok, "https://cdn/sig"} end)

      assert {:ok, _} = DownloadService.issue_url(grant)
      reloaded_1 = Ash.get!(DownloadGrant, grant.id, authorize?: false)
      assert reloaded_1.downloaded_count == 1

      assert {:ok, _} = DownloadService.issue_url(reloaded_1)
      reloaded_2 = Ash.get!(DownloadGrant, grant.id, authorize?: false)
      assert reloaded_2.downloaded_count == 2

      # Third attempt should be refused; storage must NOT be called.
      reloaded_2 = Ash.load!(reloaded_2, :digital_file, authorize?: false)
      assert {:error, :limit_reached} = DownloadService.issue_url(reloaded_2)
    end

    test "accepts unlimited downloads when download_limit is nil" do
      grant = issue_grant!()

      stub(Emakola.StorageMock, :presigned_url, fn _, _ -> {:ok, "https://cdn/sig"} end)

      for _ <- 1..3 do
        reloaded = Ash.get!(DownloadGrant, grant.id, authorize?: false)
        reloaded = Ash.load!(reloaded, :digital_file, authorize?: false)
        assert {:ok, _} = DownloadService.issue_url(reloaded)
      end

      final = Ash.get!(DownloadGrant, grant.id, authorize?: false)
      assert final.downloaded_count == 3
    end
  end

  describe "issue_url/1 — lookup variant" do
    test "issue_url/1 accepts a bare grant_id (loads the grant + file)" do
      grant = issue_grant!()

      expect(Emakola.StorageMock, :presigned_url, fn path, _opts ->
        assert path == grant.digital_file.storage_key
        {:ok, "https://cdn/sig"}
      end)

      assert {:ok, _} = DownloadService.issue_url(grant.id)
    end

    test "returns :not_found for an unknown grant_id" do
      assert {:error, :not_found} = DownloadService.issue_url(Ecto.UUID.generate())
    end
  end
end
