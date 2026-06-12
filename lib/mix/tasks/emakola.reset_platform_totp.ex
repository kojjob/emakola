defmodule Mix.Tasks.Emakola.ResetPlatformTotp do
  @moduledoc """
  Clears a user's TOTP enrolment so they can re-enrol at next sign-in.

  Usage: mix emakola.reset_platform_totp email@example.com

  Used for lockout recovery, e.g. when a staff member loses their
  authenticator device.
  """
  use Mix.Task

  require Ash.Query

  @shortdoc "Clear a user's TOTP enrolment by email"

  def run([email]) do
    Mix.Task.run("app.start")
    reset(email)
  end

  def run(_) do
    Mix.shell().error("Usage: mix emakola.reset_platform_totp <email>")
  end

  @doc false
  def reset(email) do
    case Emakola.Accounts.User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        Mix.shell().error("No user found with email #{email}")

      {:ok, user} ->
        user
        |> Ash.Changeset.for_update(:clear_totp, %{})
        |> Ash.update!(authorize?: false)

        Mix.shell().info("TOTP reset for #{email} — they will re-enrol at next sign-in")

      {:error, error} ->
        Mix.shell().error("Error: #{inspect(error)}")
    end
  end
end
