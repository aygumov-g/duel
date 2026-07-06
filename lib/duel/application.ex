defmodule Duel.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DuelWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:duel, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Duel.PubSub},
      {Registry, keys: :unique, name: Duel.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Duel.GameSupervisor},
      Duel.Game.Matchmaker,
      # Start a worker by calling: Duel.Worker.start_link(arg)
      # {Duel.Worker, arg},
      # Start to serve requests, typically the last entry
      DuelWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Duel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DuelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
