defmodule Emakola.Accounts.PlatformOwnerBootstrap do
  @moduledoc """
  Create-or-promote a platform owner by email.

  Shared by the dev mix task (`mix emakola.bootstrap_platform_owner`) and the
  prod release helper (`Emakola.Release.bootstrap_platform_owner/1`) so an owner
  is created identically in every environment. Pure of IO — each caller formats
  the result for its own shell.
  """
  require Ash.Query

  alias Emakola.Accounts.User

  @type result ::
          {:created, String.t(), String.t()}
          | {:promoted, String.t()}
          | {:error, term()}

  @doc """
  Promotes an existing user with `email` to platform owner, or creates a new
  confirmed owner with a securely random password.

  Returns `{:created, email, password}`, `{:promoted, email}`, or
  `{:error, reason}`.
  """
  @spec run(String.t()) :: result()
  def run(email) do
    case User |> Ash.Query.filter(email == ^email) |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> create_owner(email)
      {:ok, user} -> promote(user, email)
      {:error, error} -> {:error, error}
    end
  end

  defp create_owner(email) do
    password = generate_password()

    case User
         |> Ash.Changeset.for_create(:bootstrap_owner, %{email: email, password: password})
         |> Ash.create(authorize?: false) do
      {:ok, _user} -> {:created, email, password}
      {:error, error} -> {:error, error}
    end
  end

  defp promote(user, email) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, %{is_owner: true})
    |> Ash.update!(authorize?: false)

    {:promoted, email}
  end

  defp generate_password do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
