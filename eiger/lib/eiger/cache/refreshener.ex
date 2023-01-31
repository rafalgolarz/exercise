defmodule Eiger.Cache.Refreshener do
  @moduledoc """
  Keeps the data refreshed by executing registered functions at given time.
  1. start GenServer for given registered function to track cached results
  2. execute the registered function (as a Task)
  2. keep the result cached alive for time set to TTL
  3. refresh results (execute the Task) after refresh_interval

  TTL and refresh_interval are set in milliseconds.
  """

  require Logger
  use GenServer
  alias Eiger.Cache.Registry, as: Functions

  @spec start_link(%{:key => atom, optional(any) => any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{key: key} = params) do
    GenServer.start_link(__MODULE__, params, name: Functions.via_tuple(key))
  end

  @impl GenServer
  @spec init(%{
          :function => fun :: (any() -> {:ok, any()} | {:error, any()}),
          :key => any,
          :refresh_interval => non_neg_integer,
          :ttl => number,
          optional(any) => any
        }) ::
          {:ok,
           %{
             expires_at: number,
             function: fun :: (any() -> {:ok, any()} | {:error, any()}),
             key: any,
             ref: nil,
             refresh_interval: non_neg_integer,
             ttl: number
           }}
  def init(%{key: key, function: fun, ttl: ttl, refresh_interval: refresh_interval}) do
    cron(refresh_interval)

    {:ok,
     %{
       key: key,
       function: fun,
       ttl: ttl,
       expires_at: expires_at(ttl),
       ref: nil,
       refresh_interval: refresh_interval
     }}
  end

  # task ref is nil, so the task is not running yet
  # let's start it
  @impl true
  def handle_info(
        :cron,
        %{refresh_interval: refresh_interval, function: fun, key: key, ref: nil} = state
      ) do
    # we don't want to take down the caller, so async_nolink is chosen.
    task = Task.Supervisor.async_nolink(Eiger.TaskSupervisor, fn -> fun.() end)
    Logger.info("Starting function: #{key}.")
    cron(refresh_interval)

    {:noreply, %{state | ref: task.ref}}
  end

  # In this case the task is already running, so we just return :ok.
  @impl true
  def handle_info(:cron, %{refresh_interval: refresh_interval, ref: ref} = state)
      when is_reference(ref) do
    cron(refresh_interval)
    {:noreply, state}
  end

  # The task completed successfully
  @impl true
  def handle_info({ref, _answer}, %{key: key, ref: ref} = state) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Logger.info("Function #{key} completed successfullly!")
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | ref: nil}}
  end

  # The task failed
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{key: key, ref: ref} = state) do
    Logger.error("Function #{key} failed!")
    {:noreply, %{state | ref: nil}}
  end

  def handle_info(error, state) do
    Logger.error("inspect(#{error})")
    {:noreply, state}
  end

  # -----------------------------------------------------------------------------

  @spec cron(any()) :: reference
  defp cron(refresh_interval) do
    Process.send_after(self(), :cron, refresh_interval)
  end

  defp expires_at(ttl) do
    now = :os.system_time(:millisecond)
    now + ttl
  end
end
