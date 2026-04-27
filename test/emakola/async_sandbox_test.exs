defmodule Emakola.AsyncSandboxTest do
  @moduledoc """
  Pins the contract for the AsyncSandbox helper:

    * `run_async/1` returns a Task that resolves to the function's
      result (delegating to Task.async/1 + Task.await/1)
    * Spawned tasks can reach Ecto.Repo without raising under
      `async: true` test modules — the whole point of this module.
  """
  use Emakola.DataCase, async: true

  alias Emakola.AsyncSandbox

  test "run_async/1 returns the function's result via Task.await/1" do
    task = AsyncSandbox.run_async(fn -> 1 + 1 end)
    assert Task.await(task) == 2
  end

  test "spawned task can reach the Repo without DBConnection errors" do
    # If sandbox propagation is broken, this raises:
    #   ** (DBConnection.ConnectionError) could not checkout connection
    task = AsyncSandbox.run_async(fn -> Emakola.Repo.aggregate("schema_migrations", :count) end)
    assert is_integer(Task.await(task))
  end
end
