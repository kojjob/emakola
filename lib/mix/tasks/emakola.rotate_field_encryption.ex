defmodule Mix.Tasks.Emakola.RotateFieldEncryption do
  @moduledoc """
  Re-encrypts protected field shadows with the configured active key ids.

      mix emakola.rotate_field_encryption

  Add the new keys to both runtime keyrings before changing the active ids.
  Keep every old encryption key configured until this task reports zero rows on
  a second run and deployment verification is complete.
  """

  use Mix.Task

  @shortdoc "Rotate application-level field-encryption keys"

  @impl Mix.Task
  def run(args) do
    {opts, remaining, invalid} =
      OptionParser.parse(args, strict: [batch_size: :integer], aliases: [b: :batch_size])

    if remaining != [] or invalid != [] do
      Mix.raise("Usage: mix emakola.rotate_field_encryption [--batch-size N]")
    end

    Mix.Task.run("app.start")

    counts =
      Emakola.Security.SecretBackfill.rotate!(
        Emakola.Repo,
        batch_size: Keyword.get(opts, :batch_size, 500)
      )

    Enum.each(counts, fn {table, count} ->
      Mix.shell().info("#{table}: rotated #{count} row(s)")
    end)
  end
end
