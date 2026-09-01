defmodule Mix.Tasks.Emakola.QuarantineIdDocumentsTest do
  @moduledoc """
  Retention of a Ghana Card image is itself the offence under L.I. 2523, so
  this sweep has to reach every row — including approved and rejected ones,
  whose documents the old flow never cleaned up.
  """
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.Factory
  alias Emakola.Stores
  alias Emakola.Stores.StoreVerification
  alias Mix.Tasks.Emakola.QuarantineIdDocuments, as: Task

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  # The retired columns are no longer writable through any action, so legacy
  # rows have to be simulated at the database.
  defp legacy_id_document(verification, key) do
    Emakola.Repo.query!(
      "UPDATE store_verifications SET id_document_key = $1, id_type = 'ghana_card', id_number = 'GHA-1' WHERE id = $2",
      [key, Ecto.UUID.dump!(verification.id)]
    )

    Ash.get!(StoreVerification, verification.id, authorize?: false)
  end

  defp submission(status) do
    store = Factory.create_store!()

    {:ok, v} =
      Stores.submit_store_verification(
        %{store_id: store.id, business_name: "Ama Trades"},
        authorize?: false
      )

    v =
      case status do
        :pending ->
          v

        :approved ->
          elem(Stores.approve_store_verification(v, %{}, authorize?: false), 1)

        :rejected ->
          elem(Stores.reject_store_verification(v, %{reason: "x"}, authorize?: false), 1)
      end

    legacy_id_document(v, "verifications/#{store.id}/id-legacy.jpg")
  end

  test "vaults the document privately, deletes the original, and stamps the row" do
    verification = submission(:pending)
    original = verification.id_document_key

    expect(Emakola.StorageMock, :get, fn ^original -> {:ok, "card-bytes"} end)

    expect(Emakola.StorageMock, :upload, fn "card-bytes", key, opts ->
      assert key =~ "vault/retired-id/#{verification.store_id}/"
      assert Keyword.get(opts, :acl) == "private"
      {:ok, "https://s3.example/vaulted"}
    end)

    expect(Emakola.StorageMock, :delete, fn ^original -> :ok end)

    Task.quarantine()

    reloaded = Ash.get!(StoreVerification, verification.id, authorize?: false)
    assert %DateTime{} = reloaded.quarantined_at
  end

  test "sweeps approved and rejected rows too — the old flow never cleaned those" do
    approved = submission(:approved)
    rejected = submission(:rejected)

    stub(Emakola.StorageMock, :get, fn _ -> {:ok, "bytes"} end)
    stub(Emakola.StorageMock, :upload, fn _, _, _ -> {:ok, "https://s3.example/v"} end)
    stub(Emakola.StorageMock, :delete, fn _ -> :ok end)

    Task.quarantine()

    for v <- [approved, rejected] do
      reloaded = Ash.get!(StoreVerification, v.id, authorize?: false)
      assert %DateTime{} = reloaded.quarantined_at, "#{v.status} row was not swept"
    end
  end

  test "stamps a row whose object has already vanished, so the sweep can finish" do
    verification = submission(:pending)

    stub(Emakola.StorageMock, :get, fn _ -> {:error, :not_found} end)

    Task.quarantine()

    reloaded = Ash.get!(StoreVerification, verification.id, authorize?: false)
    assert %DateTime{} = reloaded.quarantined_at
  end

  test "is idempotent — a second run has nothing left to do" do
    submission(:pending)

    stub(Emakola.StorageMock, :get, fn _ -> {:ok, "bytes"} end)
    stub(Emakola.StorageMock, :upload, fn _, _, _ -> {:ok, "https://s3.example/v"} end)
    stub(Emakola.StorageMock, :delete, fn _ -> :ok end)

    Task.quarantine()

    # No further Storage calls are expected; an unexpected one fails the test.
    expect(Emakola.StorageMock, :get, 0, fn _ -> {:ok, "bytes"} end)
    Task.quarantine()
  end

  test "leaves rows that never carried an ID document alone" do
    store = Factory.create_store!()

    {:ok, v} =
      Stores.submit_store_verification(
        %{store_id: store.id, business_name: "No Card Co"},
        authorize?: false
      )

    expect(Emakola.StorageMock, :get, 0, fn _ -> {:ok, ""} end)

    Task.quarantine()

    reloaded = Ash.get!(StoreVerification, v.id, authorize?: false)
    assert is_nil(reloaded.quarantined_at)
  end

  test "purge deletes the vaulted copy only after quarantine stamped the row" do
    verification = submission(:pending)

    stub(Emakola.StorageMock, :get, fn _ -> {:ok, "bytes"} end)
    stub(Emakola.StorageMock, :upload, fn _, _, _ -> {:ok, "https://s3.example/v"} end)
    stub(Emakola.StorageMock, :delete, fn _ -> :ok end)
    Task.quarantine()

    expect(Emakola.StorageMock, :delete, fn key ->
      assert key =~ "vault/retired-id/#{verification.store_id}/"
      :ok
    end)

    Task.purge()
  end
end
