defmodule Speedtest.Ping do
  @moduledoc """
  Elixir wrapper for the ping command.
  """

  @doc """
  Ping Command.

  Ping an IP and return a tuple with the time
  `{:ok, ip, time}` 
  """
  def ping(ip) do
    try do
      {cmd_output, _} = System.cmd("ping", ["-c", "5", "-w", "5", "-s", "1", ip])
      [_ | time] = Regex.run(~r/time(.*?ms)/, cmd_output)
      [time] = time
      time = String.split(time, "m")
      time = List.first(time)
      time = String.trim(time)
      time = String.to_integer(time)

      {:ok, ip, time}
    rescue
      e -> {:error, ip, e}
    end
  end
end
