defmodule Eiger.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Eiger.Worker.start_link(arg)
      # {Eiger.Worker, arg}
      {Task.Supervisor, name: Eiger.TaskSupervisor},
      {Registry, keys: :unique, name: Eiger.Cache.Registry.name()},
      {Eiger.Cache.Manager, []},
      {Eiger.Cache, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Eiger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
