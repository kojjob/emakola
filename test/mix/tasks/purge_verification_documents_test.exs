defmodule Mix.Tasks.Emakola.PurgeVerificationDocumentsTest do
  @moduledoc """
  The Mix task is the development face of `Emakola.Stores.VerificationDocumentPurge`;
  production runs it through `Emakola.Release`. This pins only that the task
  calls through and that a dry run stays a dry run.
  """
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.Factory
  alias Emakola.Stores
  alias Mix.Tasks.Emakola.PurgeVerificationDocuments, as: Task

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    store = Factory.create_store!()

    {:ok, v} =
      Stores.submit_store_verification(
        %{store_id: store.id, business_name: "Ama Trades"},
        authorize?: false
      )

    Emakola.Repo.query!(
      "UPDATE store_verifications SET id_document_key = $1 WHERE id = $2",
      ["verifications/#{store.id}/id-legacy.jpg", Ecto.UUID.dump!(v.id)]
    )

    :ok
  end

  test "--dry-run reports and deletes nothing" do
    Task.run(["--dry-run"])

    assert_received {:mix_shell, :info, [msg]}
    assert msg =~ "1 verification"
  end

  test "a real run deletes and reports counts" do
    expect(Emakola.StorageMock, :delete, fn _key -> :ok end)

    Task.run([])

    assert_received {:mix_shell, :info, [msg]}
    assert msg =~ "Deleted 1"
  end
end
