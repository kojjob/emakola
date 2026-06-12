defmodule Mix.Tasks.Emakola.BootstrapPlatformOwner do
  @moduledoc """
  Bootstraps a platform owner by email.

  Usage: mix emakola.bootstrap_platform_owner email@example.com

  If a user with that email exists, they are promoted to platform owner.
  Otherwise a new user is created with a securely random password that is
  printed once — store it safely or change it after first sign-in.
  """
  use Mix.Task

  require Ash.Query

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
    case Emakola.Accounts.User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        create_owner(email)

      {:ok, user} ->
        promote(user)
        Mix.shell().info("#{email} is now a platform owner")

      {:error, error} ->
        Mix.shell().error("Error: #{inspect(error)}")
    end
  end

  defp create_owner(email) do
    password = generate_password()

    case Emakola.Accounts.User
         |> Ash.Changeset.for_create(:register_with_password, %{
           email: email,
           password: password,
           password_confirmation: password
         })
         |> Ash.create(authorize?: false) do
      {:ok, user} ->
        promote(user)
        Mix.shell().info("Created platform owner #{email}")
        Mix.shell().info("Temporary password (shown once): #{password}")

      {:error, error} ->
        Mix.shell().error("Could not create user: #{inspect(error)}")
    end
  end

  defp promote(user) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, %{is_owner: true})
    |> Ash.update!(authorize?: false)
  end

  defp generate_password do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
