defmodule Speedtest do
  @moduledoc """
  Speedtest.net client for Elixir.
  """

  alias Speedtest.Ping

  alias Speedtest.Decoder

  alias Speedtest.Result

  require Logger

  defstruct config: [],
            servers: [],
            include: nil,
            exclude: nil,
            threads: nil,
            selected_server: nil,
            result: nil

  @doc """
  Retrieve a the list of speedtest.net servers, optionally filtered
   to servers matching those specified in the servers argument
  """
  def fetch_servers(%Speedtest{} = speedtest \\ %Speedtest{}) do
    Logger.info("Retrieving speedtest.net server list...")

    urls = [
      "https://www.speedtest.net/speedtest-servers-static.php",
      "http://c.speedtest.net/speedtest-servers-static.php",
      "https://www.speedtest.net/speedtest-servers.php",
      "http://c.speedtest.net/speedtest-servers.php"
    ]

    first = List.first(urls)

    {_, response} = fetch_server(first)

    result = Decoder.server(response)

    result =
      case speedtest.include == nil do
        true -> result
        false -> Enum.reject(speedtest.include, fn x -> Enum.member?(result, x) == false end)
      end

    result =
      case speedtest.exclude == nil do
        true -> result
        false -> Enum.reject(speedtest.exclude, fn x -> Enum.member?(result, x) end)
      end

    reply = %{speedtest | servers: result}
    {:ok, reply}
  end

  @doc """
  Limit servers to the closest speedtest.net servers based on
  geographic distance
  """
  def choose_closest_servers(servers \\ [], amount \\ 2) do
    servers = Enum.sort_by(servers, fn s -> s.distance end)
    reply = Enum.take(servers, amount)
    reply
  end

  @doc """
  Perform a speedtest.net "ping" to determine which speedtest.net
  server has the lowest latency
  """
  def choose_best_server(servers) do
    Logger.info("Selecting best server based on ping...")

    reply =
      Enum.map(servers, fn s ->
        url = Decoder.url(s.host)
        ping = Speedtest.Ping.ping(url)
        Map.put(s, :ping, ping)
      end)

    servers = Enum.sort_by(reply, fn s -> s.ping end)

    List.first(servers)
  end

  @doc """
  Test download speed against speedtest.net
  """
  def download(%Speedtest{} = speedtest \\ %Speedtest{}) do
    Logger.info("Testing download speed...")
    {_, urls} = generate_download_urls(speedtest)

    responses =
      Enum.map(urls, fn u ->
        {time_in_microseconds, return} =
          :timer.tc(fn ->
            {_, reply} = HTTPoison.get(u)
            reply
          end)

        [{_, length}] =
          Enum.filter(return.headers, fn h ->
            {key, _} = h
            key == "Content-Length"
          end)

        %{elapsed_time: time_in_microseconds, bytes: String.to_integer(length), url: u}
      end)

    {:ok, responses}
  end

  defp calculate(data) do
    data.bytes / (1 / :math.pow(10, 3)) * data.elapsed_time
  end

  @doc """
  Test upload speed against speedtest.net
  """
  def upload(%Speedtest{} = speedtest \\ %Speedtest{}) do
    Logger.info("Testing Upload Speed...")
    {_, data} = generate_upload_data(speedtest)

    responses =
      Enum.map(data, fn {url, size} ->
        {time_in_microseconds, return} =
          :timer.tc(fn ->
            headers = [{"Content-length", size}]
            body = ""
            {_, reply} = HTTPoison.post(url, body, headers)
            reply
          end)

        %{elapsed_time: time_in_microseconds, bytes: size, url: url}
      end)

    {:ok, responses}
  end

  @doc """
  Determine distance between sets of [lat,lon] in km 
  """
  def distance(%Speedtest{} = speedtest \\ %Speedtest{}) do
    servers =
      Enum.map(speedtest.servers, fn s ->
        distance =
          Geocalc.distance_between([speedtest.config.client.lat, speedtest.config.client.lon], [
            s.lat,
            s.lon
          ])

        Map.put(s, :distance, distance)
      end)

    speedtest = %{speedtest | servers: servers}
    {:ok, speedtest}
  end

  @doc """
  Run the full speedtest.net test
  """
  def run() do
    {_, init} = init()

    {_, result} = fetch_config_data()

    config = Decoder.config(result)

    Logger.info("Testing from " <> config.client.isp <> " (" <> config.client.ip <> ")...")

    {_, result} = fetch_servers(init)

    speedtest = %{result | config: config}

    {_, result} = distance(speedtest)

    closest_servers = choose_closest_servers(result.servers)

    selected_server = choose_best_server(closest_servers)

    {_, _, ping} = selected_server.ping

    ping = to_string(ping)

    elapsed_time = ping <> " ms"

    Logger.info(
      "Hosted by " <>
        selected_server.sponsor <>
        " (" <>
        selected_server.name <>
        ") " <>
        "[" <>
        to_string(Float.round(selected_server.distance / 1000)) <> " km]: " <> elapsed_time
    )

    speedtest = %{result | selected_server: selected_server}

    {_, download_reply} = download(speedtest)

    {_, upload_reply} = upload(speedtest)

    replys = {upload_reply, download_reply}

    {_, reply} = Result.create(speedtest, replys)

    speed = to_string(Float.round(reply.result.download, 2)) <> " Mbit/s"
    Logger.info("Download: " <> speed)

    speed = to_string(Float.round(reply.result.upload, 2)) <> " Mbit/s"
    Logger.info("Upload: " <> speed)

    {:ok, reply}
  end

  @doc """
  Ping an IP and return a tuple with the time
  """
  def ping(ip) do
    Ping.ping(ip)
  end

  defp user_agent() do
    {"User-Agent",
     "Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.117 Safari/537.36"}
  end

  defp fetch_server(server) do
    HTTPoison.get(server, [user_agent()], hackney: [headers: [user_agent()]])
  end

  defp fetch_config_data() do
    Logger.info("Retrieving speedtest.net configuration...")

    {status, response} =
      HTTPoison.get(
        "https://www.speedtest.net/speedtest-config.php",
        [user_agent()],
        hackney: [headers: [user_agent()]]
      )

    {status, response}
  end

  @doc """
  Setup the base speedtest
  """
  def init() do
    threads = Application.get_env(:speedtest, :threads)
    include = Application.get_env(:speedtest, :include)
    exclude = Application.get_env(:speedtest, :exclude)
    st = %Speedtest{}
    reply = %{st | threads: threads, include: include, exclude: exclude}
    {:ok, reply}
  end

  defp generate_download_urls(%Speedtest{} = speedtest \\ %Speedtest{}) do
    urls =
      Enum.map(speedtest.config.sizes.download, fn s ->
        size = to_string(s)
        speedtest.selected_server.host <> "/speedtest/random" <> size <> "x" <> size <> ".jpg"
      end)

    urls = Enum.shuffle(urls)

    {:ok, urls}
  end

  defp generate_upload_data(%Speedtest{} = speedtest \\ %Speedtest{}) do
    data =
      Enum.map(speedtest.config.sizes.upload, fn s ->
        {speedtest.selected_server.url, to_string(s)}
      end)

    {:ok, data}
  end
end
