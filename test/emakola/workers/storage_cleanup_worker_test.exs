defmodule Emakola.Workers.StorageCleanupWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  setup :verify_on_exit!

  alias Emakola.Workers.StorageCleanupWorker

  test "deletes every key from object storage" do
    expect(Emakola.StorageMock, :delete, 2, fn key ->
      assert key in ["stores/s1/a.webp", "stores/s1/b.jpg"]
      :ok
    end)

    assert :ok =
             perform_job(StorageCleanupWorker, %{
               "keys" => ["stores/s1/a.webp", "stores/s1/b.jpg"]
             })
  end

  test "tolerates a storage failure for one key and still succeeds" do
    stub(Emakola.StorageMock, :delete, fn _key -> {:error, :boom} end)

    assert :ok = perform_job(StorageCleanupWorker, %{"keys" => ["stores/s1/missing.png"]})
  end
end
