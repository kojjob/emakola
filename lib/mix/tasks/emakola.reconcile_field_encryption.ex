defmodule Mix.Tasks.Emakola.ReconcileFieldEncryption do
  @moduledoc """
  Reconciles encrypted shadows after old nodes drain from an expand deployment.

      mix emakola.reconcile_field_encryption

  Run this after the rolling deploy is complete and before verifying that the
  legacy compatibility columns can enter their contract phase.
  """

  use Mix.Task

  @shortdoc "Reconcile encrypted shadows after a rolling deploy"

  @impl Mix.Task
  def run(args) do
    {opts, remaining, invalid} =
      OptionParser.parse(args, strict: [batch_size: :integer], aliases: [b: :batch_size])

    if remaining != [] or invalid != [] do
      Mix.raise("Usage: mix emakola.reconcile_field_encryption [--batch-size N]")
    end

    Mix.Task.run("app.start")

    counts =
      Emakola.Security.SecretBackfill.reconcile!(
        Emakola.Repo,
        batch_size: Keyword.get(opts, :batch_size, 500)
      )

    Enum.each(counts, fn {table, count} ->
      Mix.shell().info("#{table}: reconciled #{count} row(s)")
    end)
  end
end
