defmodule Mix.Tasks.Emakola.BootstrapPlatformOwnerTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Accounts.User

  require Ash.Query

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  defp shell_messages do
    {:messages, messages} = Process.info(self(), :messages)

    for {:mix_shell, :info, [msg]} <- messages, do: msg
  end

  test "promotes an existing user to platform owner" do
    user = create_user!()

    Mix.Tasks.Emakola.BootstrapPlatformOwner.bootstrap(to_string(user.email))

    assert Ash.get!(User, user.id, authorize?: false).is_owner
    assert Enum.any?(shell_messages(), &(&1 =~ "platform owner"))
    refute Enum.any?(shell_messages(), &(&1 =~ "password"))
  end

  test "creates a confirmed owner whose printed password actually works" do
    email = unique_email()

    Mix.Tasks.Emakola.BootstrapPlatformOwner.bootstrap(email)

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    assert user.is_owner
    assert Enum.any?(shell_messages(), &(&1 =~ "password"))

    # Regression: a bootstrapped owner must actually be able to sign in —
    # i.e. the account is confirmed and the printed password matches the hash.
    assert user.confirmed_at, "owner must be confirmed so they can sign in"

    password =
      Enum.find_value(shell_messages(), fn msg ->
        case Regex.run(~r/password \(shown once\): (\S+)/, msg) do
          [_, pw] -> pw
          _ -> nil
        end
      end)

    assert password, "bootstrap must print the temporary password"
    assert Bcrypt.verify_pass(password, user.hashed_password)
  end

  test "errors without exactly one email argument" do
    Mix.Tasks.Emakola.BootstrapPlatformOwner.run([])

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "Usage"
  end
end
