defmodule Eiger.Cache.Data do
  @moduledoc """
  Manages the data associated with registered functions.
  """

  require Logger
  use GenServer
  alias Eiger.Cache.Registry, as: Functions

  @spec start_link(%{:key => atom, optional(any) => any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{key: key} = params) do
    GenServer.start_link(__MODULE__, params, name: Functions.via_tuple(key))
  end

  @impl GenServer
  def init(%{key: key, function: fun, ttl: ttl, refresh_interval: refresh_interval}) do
    now = :os.system_time(:millisecond)
    refresh_cache(refresh_interval)

    {:ok,
     %{
       key: key,
       function: fun,
       ttl: ttl,
       expires_at: now + ttl,
       refresh_interval: refresh_interval
     }, {:continue, :run_tasks}}
  end

  @spec refresh_cache(non_neg_integer) :: reference
  def refresh_cache(refresh_interval) do
    Process.send_after(self(), :cron, refresh_interval)
  end

  @impl true
  def handle_info(:cron, %{refresh_interval: refresh_interval, key: key} = state) do
    Logger.info("Refreshing cache for registered function: #{key}")
    execute_task(state)
    refresh_cache(refresh_interval)
    {:noreply, state}
  end

  defp execute_task(_state) do
  end

  @impl true
  def handle_continue(:run_tasks, state) do
    {:noreply, state}
  end
end
