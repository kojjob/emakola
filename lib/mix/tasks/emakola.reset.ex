defmodule Mix.Tasks.Emakola.Reset do
  @moduledoc """
  Resets the database and re-seeds.

      mix emakola.reset
  """
  use Mix.Task

  @shortdoc "Reset database and re-seed"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("🔄 Resetting Emakola database...")

    Mix.Task.run("ecto.reset")
    Mix.Task.run("emakola.seed_plans")

    Mix.shell().info("✅ Database reset complete!")
  end
end
