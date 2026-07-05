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

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
