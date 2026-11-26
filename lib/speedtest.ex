defmodule Speedtest do
  @moduledoc """
  Speedtest.net client for Elixir.
  """

  require Logger

  alias Speedtest.{Decoder, HTTP, Ping, Result}

  @ttl 25_000
  @config_url "https://www.speedtest.net/api/js/config-sdk?engine=js&limit=10&https_functional=true"
  @server_urls [
    "https://speedtest.net",
    "https://www.speedtest.net/api/js/config-sdk?engine=js&limit=10&https_functional=true"
  ]
  @user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  defstruct config: nil,
            servers: [],
            include: nil,
            exclude: nil,
            threads: nil,
            selected_server: nil,
            result: nil

  @type t :: %__MODULE__{
               config: map() | nil,
               servers: list(map()),
               include: list(String.t()) | nil,
               exclude: list(String.t()) | nil,
               threads: pos_integer() | nil,
               selected_server: map() | nil,
               result: Result.t() | nil
             }

  @spec init() :: {:ok, t()}
  def init do
    {:ok,
      %__MODULE__{
        threads: Application.get_env(:speedtest, :threads),
        include: Application.get_env(:speedtest, :include),
        exclude: Application.get_env(:speedtest, :exclude)
      }}
  end

  @spec fetch_servers(t()) :: {:ok, t()} | {:error, term()}
  def fetch_servers(%__MODULE__{} = speedtest \\ %__MODULE__{}) do
    Logger.info("Retrieving speedtest.net server list...")

    with {:ok, response} <- fetch_first_available(@server_urls) do
      servers =
        response
        |> Decoder.server()
        |> filter_servers(speedtest.include, speedtest.exclude)

      {:ok, %{speedtest | servers: servers}}
    end
  end

  @spec distance(t()) :: {:ok, t()}
  def distance(%__MODULE__{} = speedtest \\ %__MODULE__{}) do
    client_coords = [speedtest.config.client.lat, speedtest.config.client.lon]

    servers =
      Enum.map(speedtest.servers, fn server ->
        dist =
          client_coords
          |> Geocalc.distance_between([server.lat, server.lon])
          |> round()

        Map.put(server, :distance, dist)
      end)

    {:ok, %{speedtest | servers: servers}}
  end

  @spec choose_closest_servers(list(map()), pos_integer()) :: list(map())
  def choose_closest_servers(servers \\ [], amount \\ 5) do
    servers
    |> Enum.sort_by(& &1.distance)
    |> Enum.take(amount)
  end

  @spec choose_best_server(list(map()), keyword()) :: {:ok, map()} | {:error, :no_reachable_servers}
  def choose_best_server(servers, opts \\ []) when is_list(servers) do
    Logger.info("Selecting best server based on ping...")
    ping_opts = Keyword.take(opts, [:method, :count, :timeout])

    best =
      servers
      |> Task.async_stream(
           fn server ->
             ping_result = Ping.ping(server.host, ping_opts)
             Map.put(server, :ping, ping_result)
           end,
           max_concurrency: max(length(servers), 1),
           timeout: @ttl
         )
      |> Enum.reduce([], fn
        {:ok, %{ping: {:ok, _host, _ms}} = server}, acc -> [server | acc]
        _, acc -> acc
      end)
      |> Enum.min_by(fn %{ping: {:ok, _host, ms}} -> ms end, fn -> nil end)

    case best do
      nil -> {:error, :no_reachable_servers}
      server -> {:ok, server}
    end
  end

  @spec download(t()) :: {:ok, list(map())}
  def download(%__MODULE__{} = speedtest \\ %__MODULE__{}) do
    Logger.info("Testing download speed...")
    urls = generate_download_urls(speedtest)
    concurrency = speedtest.threads || speedtest.config.threads.download

    responses =
      urls
      |> Task.async_stream(&timed_fetch/1,
           max_concurrency: concurrency,
           timeout: @ttl + 5_000,
           on_timeout: :kill_task
         )
      |> Enum.flat_map(fn
        {:ok, {:ok, sample}} -> [sample]
        _ -> []
      end)

    {:ok, responses}
  end

  @spec upload(t()) :: {:ok, list(map())}
  def upload(%__MODULE__{} = speedtest \\ %__MODULE__{}) do
    Logger.info("Testing upload speed...")
    payloads = generate_upload_data(speedtest)
    concurrency = speedtest.threads || speedtest.config.threads.upload

    responses =
      payloads
      |> Task.async_stream(
           fn {url, size} -> timed_post(url, size) end,
           max_concurrency: concurrency,
           timeout: @ttl + 5_000,
           on_timeout: :kill_task
         )
      |> Enum.flat_map(fn
        {:ok, {:ok, sample}} -> [sample]
        _ -> []
      end)

    {:ok, responses}
  end

  @spec run(keyword()) :: {:ok, t()} | {:error, term()}
  def run(opts \\ []) do
    with {:ok, st} <- init(),
         {:ok, config_resp} <- fetch_config_data(),
         config = Decoder.config(config_resp),
         _ = Logger.info("Testing from #{config.client.isp} (#{config.client.ip})..."),
         st = %{st | config: config, exclude: merge_ignored(st.exclude, config.ignore_servers)},
         {:ok, st} <- fetch_servers(st),
         {:ok, st} <- distance(st),
         closest = choose_closest_servers(st.servers),
         {:ok, best_server} <- choose_best_server(closest, opts),
         {:ok, _host, ping_ms} = best_server.ping do
      dist_km = round(best_server.distance / 1000)

      Logger.info(
        "Hosted by #{best_server.sponsor} (#{best_server.name}) [#{dist_km} km]: #{ping_ms} ms"
      )

      st = %{st | selected_server: best_server}

      with {:ok, download_reply} <- download(st),
           {:ok, upload_reply} <- upload(st),
           {:ok, st} <- Result.create(st, {upload_reply, download_reply}) do
        Logger.info("Download: #{st.result.download} Mbit/s")
        Logger.info("Upload: #{st.result.upload} Mbit/s")

        updated_config = %{st.config | client: st.result.client}
        {:ok, %{st | config: updated_config}}
      end
    end
  end

  @spec ping(String.t(), keyword()) :: Ping.ping_result()
  def ping(target, opts \\ []), do: Ping.ping(target, opts)

  # --- Private Helpers ---

  defp merge_ignored(exclude, nil), do: exclude
  defp merge_ignored(exclude, ""), do: exclude

  defp merge_ignored(exclude, ignore_csv) do
    ignored = String.split(ignore_csv, ",", trim: true)
    (exclude || []) ++ ignored
  end

  defp filter_servers(servers, include, exclude) do
    servers
    |> maybe_include(include)
    |> maybe_exclude(exclude)
  end

  defp maybe_include(servers, nil), do: servers
  defp maybe_include(servers, []), do: servers

  defp maybe_include(servers, include_ids) do
    ids = MapSet.new(include_ids, &to_string/1)
    Enum.filter(servers, &MapSet.member?(ids, &1.id))
  end

  defp maybe_exclude(servers, nil), do: servers
  defp maybe_exclude(servers, []), do: servers

  defp maybe_exclude(servers, exclude_ids) do
    ids = MapSet.new(exclude_ids, &to_string/1)
    Enum.reject(servers, &MapSet.member?(ids, &1.id))
  end

  defp generate_download_urls(%__MODULE__{} = speedtest) do
    speedtest.config.sizes.download
    |> Enum.map(fn size ->
      "http://#{speedtest.selected_server.host}/speedtest/random#{size}x#{size}.jpg"
    end)
    |> Enum.shuffle()
  end

  defp generate_upload_data(%__MODULE__{} = speedtest) do
    Enum.map(speedtest.config.sizes.upload, fn size ->
      {speedtest.selected_server.url, size}
    end)
  end

  defp timed_fetch(url) do
    {elapsed_us, result} =
      :timer.tc(fn ->
        HTTP.client().get(url, default_headers(), follow_redirect: true, recv_timeout: @ttl)
      end)

    with {:ok, %{status_code: 200, headers: headers, body: body}} <- result do
      bytes = content_length(headers, body)
      {:ok, %{elapsed_time: elapsed_us / 1_000_000, bytes: bytes, url: url}}
    else
      {:ok, %{status_code: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp timed_post(url, size) when is_integer(size) do
    payload = :binary.copy("0", size)
    headers = [{"Content-Type", "application/x-www-form-urlencoded"} | default_headers()]

    {elapsed_us, result} =
      :timer.tc(fn ->
        HTTP.client().post(url, payload, headers, follow_redirect: true, recv_timeout: @ttl)
      end)

    with {:ok, %{status_code: 200}} <- result do
      {:ok, %{elapsed_time: elapsed_us / 1_000_000, bytes: size, url: url}}
    else
      {:ok, %{status_code: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp content_length(headers, body) do
    case Enum.find(headers, fn {k, _v} -> String.downcase(k) == "content-length" end) do
      {_, len} -> String.to_integer(len)
      nil -> byte_size(body)
    end
  end

  defp fetch_first_available([]), do: {:error, :all_server_urls_failed}

  defp fetch_first_available([url | rest]) do
    case http_get(url) do
      {:ok, %{status_code: 200, body: body} = resp} ->
        if json_body?(body), do: {:ok, resp}, else: fetch_first_available(rest)

      _ ->
        fetch_first_available(rest)
    end
  end

  def fetch_config_data do
    Logger.info("Retrieving speedtest.net configuration...")

    case http_get(@config_url) do
      {:ok, %{status_code: 200, body: body} = resp} ->
        if json_body?(body), do: {:ok, resp}, else: {:error, :unexpected_non_json_response}

      {:ok, %{status_code: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp json_body?(body) when is_binary(body) do
    trimmed = String.trim_leading(body)
    String.starts_with?(trimmed, "{") or String.starts_with?(trimmed, "[")
  end

  defp json_body?(_), do: false

  defp http_get(url) do
    HTTP.client().get(url, default_headers(), follow_redirect: true, recv_timeout: @ttl)
  end

  defp default_headers do
    [{"User-Agent", @user_agent}, {"Accept", "application/json"}]
  end
end
