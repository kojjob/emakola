defmodule Mix.Tasks.Emakola.PurgeVerificationDocuments do
  @shortdoc "Deletes the documents the retired verification flows stored"

  @moduledoc """
  Deletes every ID image and business paper the retired verification flows
  put in object storage, and stamps each row `documents_purged_at`.

      mix emakola.purge_verification_documents --dry-run   # list, change nothing
      mix emakola.purge_verification_documents             # delete

  Why delete rather than move: the only bucket is public bucket-wide and the
  provider ignores per-object ACLs under it, so there is no private place to
  move to — and under L.I. 2523 retaining the ID image is itself the offence.

  This is the development face. Production runs a release, which ships no Mix,
  so there it is:

      bin/emakola rpc 'Emakola.Release.purge_verification_documents(true)'   # dry run
      bin/emakola rpc 'Emakola.Release.purge_verification_documents()'

  Both call `Emakola.Stores.VerificationDocumentPurge`.
  """

  use Mix.Task

  alias Emakola.Stores.VerificationDocumentPurge

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    if "--dry-run" in args do
      rows = VerificationDocumentPurge.pending_rows()
      Mix.shell().info("#{length(rows)} verification(s) still hold a stored document:")

      for row <- rows do
        Mix.shell().info(
          "  #{row.store_id}  #{row.id_document_key || "-"}  #{row.business_doc_key || "-"}"
        )
      end

      Mix.shell().info("\nDry run — nothing changed. Run without --dry-run to delete them.")
    else
      result = VerificationDocumentPurge.run()

      Mix.shell().info(
        "Deleted #{result.objects} object(s) across #{result.rows} row(s); " <>
          "#{result.failed} row(s) left for a re-run."
      )
    end
  end
end
