defmodule SpeedtestTest do
  use ExUnit.Case
  doctest Speedtest

  test "Fetch Speedtest.net servers" do
    {status, _} = Speedtest.fetch_servers()
    assert status == :ok
  end

  test "Run the Speedtest" do
    {status, _} = Speedtest.run()
    assert status == :ok
  end
end
