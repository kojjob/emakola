defmodule Emakola.Stores.VerificationDocumentPurgeTest do
  @moduledoc """
  Retention of an identity document is itself the offence under L.I. 2523,
  and the bucket these were written to is public bucket-wide, so "move it
  somewhere private" was never available. The only honest tool deletes.

  The sweep has to reach every row — including approved and rejected ones,
  whose documents the old flow never cleaned up — and it has to be safe to
  re-run after a partial failure.
  """
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.Factory
  alias Emakola.Stores
  alias Emakola.Stores.StoreVerification
  alias Emakola.Stores.VerificationDocumentPurge, as: Purge

  setup :verify_on_exit!
  setup :set_mox_global

  # Neither key is writable through any action any more, so legacy rows are
  # simulated at the database — exactly what production holds.
  defp with_legacy_documents(verification, id_key, business_key) do
    Emakola.Repo.query!(
      "UPDATE store_verifications SET id_document_key = $1, business_doc_key = $2, id_type = 'ghana_card', id_number = 'GHA-1' WHERE id = $3",
      [id_key, business_key, Ecto.UUID.dump!(verification.id)]
    )

    reload(verification)
  end

  defp reload(verification), do: Ash.get!(StoreVerification, verification.id, authorize?: false)

  defp submission(status \\ :pending) do
    store = Factory.create_store!()

    {:ok, v} =
      Stores.submit_store_verification(
        %{store_id: store.id, business_name: "Ama Trades"},
        authorize?: false
      )

    case status do
      :pending -> v
      :approved -> elem(Stores.approve_store_verification(v, %{}, authorize?: false), 1)
      :rejected -> elem(Stores.reject_store_verification(v, %{reason: "x"}, authorize?: false), 1)
    end
  end

  test "deletes the ID document and the business paper, then stamps the row" do
    v =
      submission()
      |> with_legacy_documents("verifications/s/id-a.jpg", "verifications/s/business-a.pdf")

    expect(Emakola.StorageMock, :delete, 2, fn key ->
      assert key in ["verifications/s/id-a.jpg", "verifications/s/business-a.pdf"]
      :ok
    end)

    assert %{rows: 1, objects: 2, failed: 0} = Purge.run()

    assert reload(v).documents_purged_at,
           "the row was not stamped, so the next sweep would try to delete again forever"
  end

  test "a row holding only a business paper is swept too" do
    v = submission() |> with_legacy_documents(nil, "verifications/s/business-only.pdf")

    expect(Emakola.StorageMock, :delete, fn "verifications/s/business-only.pdf" -> :ok end)

    assert %{rows: 1, objects: 1, failed: 0} = Purge.run()
    assert reload(v).documents_purged_at
  end

  test "sweeps approved and rejected rows — the old flow never cleaned those up" do
    approved = submission(:approved) |> with_legacy_documents("verifications/a/id.jpg", nil)
    rejected = submission(:rejected) |> with_legacy_documents("verifications/r/id.jpg", nil)

    expect(Emakola.StorageMock, :delete, 2, fn _key -> :ok end)

    assert %{rows: 2, objects: 2, failed: 0} = Purge.run()
    assert reload(approved).documents_purged_at
    assert reload(rejected).documents_purged_at
  end

  test "a storage failure leaves the row unstamped so a re-run retries it" do
    v = submission() |> with_legacy_documents("verifications/s/id-flaky.jpg", nil)

    expect(Emakola.StorageMock, :delete, fn _key -> {:error, :timeout} end)
    assert %{rows: 1, objects: 0, failed: 1} = Purge.run()
    refute reload(v).documents_purged_at, "a row was stamped purged while its object still exists"

    expect(Emakola.StorageMock, :delete, fn _key -> :ok end)
    assert %{rows: 1, objects: 1, failed: 0} = Purge.run()
    assert reload(v).documents_purged_at
  end

  test "is idempotent — a second run has nothing left to do" do
    submission() |> with_legacy_documents("verifications/s/id-once.jpg", nil)

    expect(Emakola.StorageMock, :delete, fn _key -> :ok end)
    assert %{rows: 1} = Purge.run()

    # No expectation set: any further delete would fail verify_on_exit!.
    assert %{rows: 0, objects: 0, failed: 0} = Purge.run()
  end

  test "leaves rows that never carried a document alone" do
    v = submission()

    assert %{rows: 0, objects: 0, failed: 0} = Purge.run()
    refute reload(v).documents_purged_at
  end

  test "a dry run counts what it would delete and touches nothing" do
    v =
      submission()
      |> with_legacy_documents("verifications/s/id-dry.jpg", "verifications/s/biz-dry.pdf")

    # No delete expectation: a dry run that deletes fails verify_on_exit!.
    assert %{rows: 1, objects: 2, failed: 0} = Purge.run(dry_run?: true)
    refute reload(v).documents_purged_at
  end

  test "the result names no keys, so it is safe in a deploy log" do
    submission() |> with_legacy_documents("verifications/s/id-secret.jpg", nil)
    expect(Emakola.StorageMock, :delete, fn _key -> :ok end)

    result = Purge.run()

    refute inspect(result) =~ "id-secret"
  end
end
