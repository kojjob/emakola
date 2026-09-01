defmodule Emakola.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix installed.
  """
  @app :emakola

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Backfills encrypted shadow columns after the expand migrations have run.

  Invoke this against a running production release so the work happens outside
  the migration transaction and each database statement can commit promptly:

      bin/emakola rpc 'Emakola.Release.backfill_field_encryption(500)'

  The returned map contains row counts only; it never contains secret values.
  """
  @spec backfill_field_encryption(pos_integer()) :: %{
          required(String.t()) => non_neg_integer()
        }
  def backfill_field_encryption(batch_size \\ 500) do
    field_encryption_operation(:run!, batch_size)
  end

  @doc """
  Deletes the documents the retired verification flows stored.

  Every ID image and business paper went into the public bucket, which cannot
  be made private per object on Tigris — and under L.I. 2523 retaining the ID
  image is itself the offence. Dry run first; it lists counts and writes nothing:

      bin/emakola rpc 'Emakola.Release.purge_verification_documents(true)'
      bin/emakola rpc 'Emakola.Release.purge_verification_documents()'

  Returns counts only — no keys — so it is safe in a deploy log.
  """
  @spec purge_verification_documents(boolean()) ::
          Emakola.Stores.VerificationDocumentPurge.result()
  def purge_verification_documents(dry_run? \\ false) do
    Emakola.Stores.VerificationDocumentPurge.run(dry_run?: dry_run?)
  end

  @doc """
  Reconciles encrypted shadows after all old nodes have drained.

      bin/emakola rpc 'Emakola.Release.reconcile_field_encryption(500)'
  """
  @spec reconcile_field_encryption(pos_integer()) :: %{
          required(String.t()) => non_neg_integer()
        }
  def reconcile_field_encryption(batch_size \\ 500) do
    field_encryption_operation(:reconcile!, batch_size)
  end

  @doc """
  Re-encrypts shadows with the active encryption and blind-index keys.

      bin/emakola rpc 'Emakola.Release.rotate_field_encryption(500)'
  """
  @spec rotate_field_encryption(pos_integer()) :: %{
          required(String.t()) => non_neg_integer()
        }
  def rotate_field_encryption(batch_size \\ 500) do
    field_encryption_operation(:rotate!, batch_size)
  end

  @doc """
  Creates or promotes the platform owner with `email` in production, where Mix
  (and the `emakola.bootstrap_platform_owner` task) isn't available.

  Run against the live release node with `rpc` so the returned status — including
  any one-time temporary password — is printed to your terminal, and never the
  log pipeline:

      bin/emakola rpc 'Emakola.Release.bootstrap_platform_owner("you@example.com")'

  (`eval` won't do — it runs a fresh node without the app started and discards
  the return value.) The create-or-promote logic is shared with the dev mix task
  via `Emakola.Accounts.PlatformOwnerBootstrap`, so owners are created
  identically in every environment.
  """
  @spec bootstrap_platform_owner(String.t()) :: String.t()
  def bootstrap_platform_owner(email) do
    case Emakola.Accounts.PlatformOwnerBootstrap.run(email) do
      {:created, email, password} ->
        "Created platform owner #{email} — temporary password (shown once): #{password}"

      {:promoted, email} ->
        "#{email} is now a platform owner"

      {:error, error} ->
        "Error: #{inspect(error)}"
    end
  end

  defp field_encryption_operation(operation, batch_size)
       when operation in [:run!, :reconcile!, :rotate!] and is_integer(batch_size) and
              batch_size > 0 do
    apply(Emakola.Security.SecretBackfill, operation, [Emakola.Repo, [batch_size: batch_size]])
  end

  defp field_encryption_operation(_operation, batch_size) do
    raise ArgumentError, "batch_size must be a positive integer, got: #{inspect(batch_size)}"
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
