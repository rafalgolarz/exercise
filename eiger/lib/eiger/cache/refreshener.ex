defmodule Eiger.Cache.Refreshener do
  @moduledoc """
  Keeps the data refreshed by executing registered functions at given time.
  1. start GenServer for given registered function to track cached results
  2. execute the registered function (as a Task)
  3. keep the result cached alive for time set to TTL
  4. refresh results (execute the Task) after refresh_interval
  5. update expired_at after the refresh

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
             ttl: number,
             function: fun :: (any() -> {:ok, any()} | {:error, any()}),
             function_result: any,
             ref: reference(),
             key: any,
             expires_at: number,
             refresh_interval: non_neg_integer
           }}
  def init(%{key: key, function: fun, ttl: ttl, refresh_interval: refresh_interval}) do
    cron(refresh_interval)
    task = execute_function(key, fun)

    {:ok,
     %{
       key: key,
       function: fun,
       function_result: nil,
       ref: task.ref,
       ttl: ttl,
       expires_at: expires_at(ttl),
       refresh_interval: refresh_interval
     }}
  end

  @spec get(atom, :infinity | non_neg_integer) :: any
  def get(key, timeout) do
    %{function_result: function_result, ref: ref} =
      key
      |> Functions.via_tuple()
      |> GenServer.call(:get, timeout)

    {function_result, ref}
  end

  # ----------------------------------------------------------------------------
  @impl GenServer
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  # task ref is nil, so the task is not running yet
  # let's start it
  @impl true
  def handle_call(
        :cron,
        _from,
        %{refresh_interval: refresh_interval, function: fun, key: key, ref: nil} = state
      ) do
    # we don't want to take down the caller, so async_nolink is chosen.
    task = execute_function(key, fun)
    cron(refresh_interval)

    {:reply, state, %{state | ref: task.ref}}
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
  def handle_info({ref, result}, %{key: key, ref: ref, ttl: ttl} = state) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Logger.info("Function #{key} completed successfullly!")
    {:ok, res} = result
    Process.demonitor(ref, [:flush])

    {:noreply, %{state | ref: nil, function_result: res, expires_at: expires_at(ttl)}}
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

  # ----------------------------------------------------------------------------
  defp execute_function(key, fun) do
    Logger.info("Starting function: #{key}.")
    Task.Supervisor.async_nolink(Eiger.TaskSupervisor, fn -> fun.() end)
  end

  @spec cron(any()) :: reference
  defp cron(refresh_interval) do
    Process.send_after(self(), :cron, refresh_interval)
  end

  defp expires_at(ttl) do
    now = :os.system_time(:millisecond)
    now + ttl
  end

  defp expired?(expires_at) do
    now = :os.system_time(:millisecond)
    now > expires_at
  end
end
