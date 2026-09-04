defmodule Emakola.Stores.VerificationDocumentPurge do
  @moduledoc """
  Deletes every document the retired verification flows stored.

  Two kinds were collected: a national ID image, and a "business paper" (MMDA
  licence, tax receipt). Both landed in the one bucket that also serves every
  product photo — a bucket that is public bucket-wide, on a provider that
  ignores per-object private ACLs. So there was never a private place to move
  them to, and under L.I. 2523 retaining the ID image is itself the offence.
  The only honest tool deletes.

  Sweeps rows in **every** status: documents were only ever cleaned up on
  merchant resubmit, so approved and rejected submissions still hold theirs.

  Safe to re-run. A row is stamped `documents_purged_at` only once every object
  it pointed at is gone; a storage failure leaves it unstamped, so the next run
  retries exactly that row. Deleting an already-absent object is a success —
  S3 and the local adapter both treat it as one — so a row whose object vanished
  long ago still gets stamped and the sweep can finish.

  Runs in production through `Emakola.Release.purge_verification_documents/1`
  (a release ships no Mix); `mix emakola.purge_verification_documents` is the
  development face. Returns counts only — never a key — so the result is safe
  in a deploy log.
  """

  require Logger

  alias Emakola.Storage
  alias Emakola.Stores.StoreVerification

  @type result :: %{
          rows: non_neg_integer(),
          objects: non_neg_integer(),
          failed: non_neg_integer()
        }

  @doc """
  Deletes stored documents and stamps their rows.

  `dry_run?: true` counts the rows and objects it would touch and changes
  nothing — `objects` is then "would delete".
  """
  @spec run(keyword()) :: result()
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, false)
    rows = pending_rows()

    if dry_run? do
      %{rows: length(rows), objects: rows |> Enum.map(&length(keys(&1))) |> Enum.sum(), failed: 0}
    else
      Enum.reduce(rows, %{rows: length(rows), objects: 0, failed: 0}, &purge_row/2)
    end
  end

  @doc "The rows a sweep would visit. For the development dry run's listing only."
  @spec pending_rows() :: [StoreVerification.t()]
  def pending_rows do
    StoreVerification
    |> Ash.Query.for_read(:list_with_stored_documents)
    |> Ash.read!(authorize?: false)
  end

  defp purge_row(verification, acc) do
    keys = keys(verification)
    {deleted, failed} = Enum.split_with(keys, &(Storage.delete(&1) == :ok))

    case failed do
      [] ->
        stamp(verification)
        %{acc | objects: acc.objects + length(deleted)}

      _some ->
        Logger.warning(
          "VerificationDocumentPurge: #{length(failed)} object(s) for verification " <>
            "#{verification.id} could not be deleted; row left for the next run"
        )

        %{acc | objects: acc.objects + length(deleted), failed: acc.failed + 1}
    end
  end

  defp keys(verification) do
    Enum.reject([verification.id_document_key, verification.business_doc_key], &is_nil/1)
  end

  defp stamp(verification) do
    verification
    |> Ash.Changeset.for_update(:mark_documents_purged, %{})
    |> Ash.update!(authorize?: false)
  end
end
