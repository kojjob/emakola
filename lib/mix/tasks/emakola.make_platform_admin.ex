defmodule Mix.Tasks.Emakola.MakePlatformAdmin do
  @moduledoc "Flags a user as platform admin by email. Usage: mix emakola.make_platform_admin user@example.com"
  use Mix.Task

  require Ash.Query

  @shortdoc "Grant platform admin access to a user"

  def run([email]) do
    Mix.Task.run("app.start")

    case Emakola.Accounts.User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        Mix.shell().error("User not found: #{email}")

      {:ok, user} ->
        user
        |> Ash.Changeset.for_update(:update, %{is_platform_admin: true})
        |> Ash.update!(authorize?: false)

        Mix.shell().info("#{email} is now a platform admin")

      {:error, error} ->
        Mix.shell().error("Error: #{inspect(error)}")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix emakola.make_platform_admin <email>")
  end
end
