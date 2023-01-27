defmodule Eiger.CacheTest do
  @moduledoc false
  use ExUnit.Case

  alias Eiger.Cache

  describe "register_function/4" do
    test "register new function successfullly" do
      assert :ok == Cache.register_function(fn -> {:ok, :data} end, :storm, 1000, 10)
    end

    test "check if function is already registered" do
      Cache.register_function(fn -> {:ok, :data} end, :weather, 1000, 10)

      assert {:error, :already_registered} ==
               Cache.register_function(fn -> {:ok, :data} end, :weather, 1000, 10)
    end
  end
end
