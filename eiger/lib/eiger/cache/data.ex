defmodule Eiger.Cache.Data do
  @moduledoc """
  Manages the data associated with registered function.
  """

  use GenServer
  alias Eiger.Cache.Registry, as: Functions

  @spec start_link(%{:key => atom, optional(any) => any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{key: key} = params) do
    GenServer.start_link(__MODULE__, params, name: Functions.via_tuple(key))
  end

  @spec init(any) :: {:ok, any}
  def init(params) do
    {:ok, params}
  end
end
