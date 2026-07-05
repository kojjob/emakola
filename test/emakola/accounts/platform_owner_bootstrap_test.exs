defmodule Emakola.Accounts.PlatformOwnerBootstrapTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Accounts.PlatformOwnerBootstrap
  alias Emakola.Accounts.User

  require Ash.Query

  test "promotes an existing user to platform owner" do
    user = create_user!()

    assert {:promoted, email} = PlatformOwnerBootstrap.run(to_string(user.email))
    assert email == to_string(user.email)
    assert Ash.get!(User, user.id, authorize?: false).is_owner
  end

  test "creates a confirmed owner whose returned password actually works" do
    email = unique_email()

    assert {:created, ^email, password} = PlatformOwnerBootstrap.run(email)

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    # Owner must be sign-in-ready: confirmed, and the returned password matches.
    assert user.is_owner
    assert user.confirmed_at, "owner must be confirmed so they can sign in"
    assert Bcrypt.verify_pass(password, user.hashed_password)
  end
end
