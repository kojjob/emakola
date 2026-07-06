defmodule Mix.Tasks.Emakola.BootstrapPlatformOwner do
  @moduledoc """
  Bootstraps a platform owner by email.

  Usage: mix emakola.bootstrap_platform_owner email@example.com

  If a user with that email exists, they are promoted to platform owner.
  Otherwise a new user is created with a securely random password that is
  printed once — store it safely or change it after first sign-in.

  In production (no Mix), use `Emakola.Release.bootstrap_platform_owner/1`.
  """
  use Mix.Task

  alias Emakola.Accounts.PlatformOwnerBootstrap

  @shortdoc "Create or promote a platform owner by email"

  def run([email]) do
    Mix.Task.run("app.start")
    bootstrap(email)
  end

  def run(_) do
    Mix.shell().error("Usage: mix emakola.bootstrap_platform_owner <email>")
  end

  @doc false
  def bootstrap(email) do
    case PlatformOwnerBootstrap.run(email) do
      {:created, email, password} ->
        Mix.shell().info("Created platform owner #{email}")
        Mix.shell().info("Temporary password (shown once): #{password}")

      {:promoted, email} ->
        Mix.shell().info("#{email} is now a platform owner")

      {:error, error} ->
        Mix.shell().error("Error: #{inspect(error)}")
    end
  end
end
