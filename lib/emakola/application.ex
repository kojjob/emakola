defmodule Emakola.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EmakolaWeb.Telemetry,
      Emakola.Repo,
      {DNSCluster, query: Application.get_env(:emakola, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Emakola.PubSub},
      {Finch, name: Emakola.Finch},
      {Oban, Application.fetch_env!(:emakola, Oban)},
      # Start to serve requests, typically the last entry
      EmakolaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emakola.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmakolaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
