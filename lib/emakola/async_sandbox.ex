defmodule Emakola.AsyncSandbox do
  @moduledoc """
  Wraps `Task.async/1` so that spawned Tasks can use the parent
  process's Ecto sandbox connection when running under
  `async: true` test modules.

  Production builds compile out the test-only propagation via a
  module-level `Mix.env()` guard, so this helper is zero-cost
  outside the test suite.

  ## Why this exists

  `Ecto.Adapters.SQL.Sandbox` grants connection ownership to the
  test process. A `Task.async` spawned by code-under-test runs in
  a fresh process that owns no connection, so its first DB call
  hits `DBConnection.ConnectionError`. Calling `Sandbox.allow/3`
  from inside the spawned Task lets it borrow the parent's
  connection.

  Use this anywhere production code spawns parallel queries.
  """

  @doc """
  Wraps `Task.async/1` and propagates Ecto sandbox ownership in
  the test environment. Returns the `Task` struct as
  `Task.async/1` would.
  """
  @spec run_async((-> term())) :: Task.t()
  def run_async(fun) when is_function(fun, 0) do
    parent = self()

    Task.async(fn ->
      maybe_allow_sandbox(parent)
      fun.()
    end)
  end

  if Mix.env() == :test do
    defp maybe_allow_sandbox(parent) do
      Ecto.Adapters.SQL.Sandbox.allow(Emakola.Repo, parent, self())
    end
  else
    defp maybe_allow_sandbox(_parent), do: :ok
  end
end
