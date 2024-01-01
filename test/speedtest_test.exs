defmodule SpeedtestTest do
  use ExUnit.Case

  test "Fetch Speedtest.net servers" do
    {status, _} = Speedtest.fetch_servers()
    assert status == :ok
  end

  test "Run the Speedtest" do
    {status, _} = Speedtest.run()

    case Mix.env() do
      :test ->
        assert status == :ok

      :circleci ->
        assert status == :error
    end
  end
end
