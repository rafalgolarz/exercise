defmodule Eiger.CacheSpeedTest do
  @moduledoc false
  use ExUnit.Case

  alias Eiger.Cache

  describe "get/2" do
    test "register and get" do
      Cache.register_function(
        fn ->
          Process.sleep(1000)
          {:ok, :sleep}
        end,
        :sleep,
        1000,
        10
      )

      Cache.register_function(
        fn ->
          {:ok, :quick}
        end,
        :quick,
        1000,
        10
      )

      assert Cache.get(:sleep) == {:error, :timeout}
      assert Cache.get(:quick) == {:ok, :quick}
    end
  end
end
