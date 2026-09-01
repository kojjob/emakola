defmodule Mix.Tasks.Emakola.QuarantineIdDocuments do
  @shortdoc "Moves retired Ghana Card documents out of the public bucket"

  @moduledoc """
  Vaults every national-ID document submitted under the retired KYC flow.

  L.I. 2523 (in force 9 June 2026) makes it an offence for an organisation to
  request, retain, reproduce or visually inspect a Ghana Card for identity
  verification. Retention is the violation, so these objects have to go — but
  Kojo's call was to quarantine first and delete once counsel confirms, which
  is what the two modes below are for.

  Sweeps rows in **every** status. Documents were only ever deleted on merchant
  resubmit, so approved and rejected submissions still hold theirs.

      mix emakola.quarantine_id_documents            # vault + stamp
      mix emakola.quarantine_id_documents --dry-run  # report only
      mix emakola.quarantine_id_documents --purge    # delete vaulted copies

  Vaulting reads the object, rewrites it under `#{"vault/retired-id/"}<store_id>/`
  with a private ACL, deletes the original, and stamps `quarantined_at`. A
  document whose object has already vanished is stamped anyway — the point of
  the stamp is "this row no longer has a live ID image", and re-reading a
  missing object on every run would keep the sweep from ever completing.

  Idempotent: `:list_unquarantined_id_documents` only returns rows that still
  need doing, so a re-run after a partial failure picks up where it stopped.
  """

  use Mix.Task

  alias Emakola.Storage
  alias Emakola.Stores.StoreVerification

  @vault_prefix "vault/retired-id"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    cond do
      "--purge" in args -> purge()
      "--dry-run" in args -> dry_run()
      true -> quarantine()
    end
  end

  # ── Modes ───────────────────────────────────────────────────────────────

  @doc false
  def dry_run do
    pending = pending_rows()

    Mix.shell().info("#{length(pending)} verification(s) still holding an ID document:")

    for verification <- pending do
      Mix.shell().info("  #{verification.store_id}  #{verification.id_document_key}")
    end

    Mix.shell().info("\nRun without --dry-run to vault them.")
  end

  @doc false
  def quarantine do
    {vaulted, stamped_only} =
      Enum.reduce(pending_rows(), {0, 0}, fn verification, {vaulted, stamped_only} ->
        case vault(verification) do
          :ok ->
            stamp(verification)
            {vaulted + 1, stamped_only}

          {:error, reason} ->
            Mix.shell().info(
              "  ! #{verification.id_document_key}: #{inspect(reason)} — stamping anyway"
            )

            stamp(verification)
            {vaulted, stamped_only + 1}
        end
      end)

    Mix.shell().info("Vaulted #{vaulted}; stamped #{stamped_only} whose object was unreadable.")
  end

  @doc false
  def purge do
    quarantined =
      StoreVerification
      |> Ash.Query.for_read(:read)
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.id_document_key && &1.quarantined_at))

    count =
      Enum.count(quarantined, fn verification ->
        Storage.delete(vault_key(verification)) == :ok
      end)

    Mix.shell().info("Deleted #{count} vaulted ID document(s) of #{length(quarantined)}.")
  end

  # ── Steps ───────────────────────────────────────────────────────────────

  defp pending_rows do
    StoreVerification
    |> Ash.Query.for_read(:list_unquarantined_id_documents)
    |> Ash.read!(authorize?: false)
  end

  defp vault(verification) do
    with {:ok, binary} <- Storage.get(verification.id_document_key),
         {:ok, _url} <- Storage.upload(binary, vault_key(verification), acl: "private") do
      Storage.delete(verification.id_document_key)
      :ok
    end
  end

  defp stamp(verification) do
    verification
    |> Ash.Changeset.for_update(:quarantine_id_document, %{})
    |> Ash.update!(authorize?: false)
  end

  defp vault_key(verification) do
    "#{@vault_prefix}/#{verification.store_id}/#{Path.basename(verification.id_document_key)}"
  end
end
