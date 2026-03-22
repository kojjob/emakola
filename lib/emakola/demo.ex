defmodule Emakola.Demo do
  @moduledoc """
  Demo mode support. When DEMO_MODE=true, mutations are blocked
  and a seeded read-only account is available.
  """

  def enabled? do
    Application.get_env(:emakola, :demo_mode, false)
  end

  def demo_email, do: "demo@founderpad.io"
  def demo_password, do: "DemoPassword123!"
end
