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
    {cmd_output, _} = System.cmd("ping", ["-c", "1", ip])
    [_ | [time]] = Regex.run(~r/time=(.*? ms)/, cmd_output)

    {time, ""} =
      time
      |> String.split(" ")
      |> List.first()
      |> Float.parse()

    time
  end
end
