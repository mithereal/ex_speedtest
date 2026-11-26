defmodule Speedtest.Ping do
  @moduledoc """
  Latency measurement for Speedtest servers.

  Supports two probing modes:
    * `:http` (default) — Measures round-trip HTTP latency against
      `/speedtest/latency.txt` (official Speedtest behavior; works inside
      containers/Render without raw ICMP socket permissions).
    * `:icmp` — Uses the system `ping` binary (Linux, macOS, and Alpine/BusyBox).
  """

  alias Speedtest.{Decoder, HTTP}

  @default_count 5
  @default_timeout 5_000
  @user_agent "Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.117 Safari/537.36"

  @type method :: :http | :icmp
  @type ping_result :: {:ok, String.t(), float()} | {:error, String.t(), term()}

  @doc """
  Measures latency to a target host/IP and returns `{:ok, target, avg_ms}` or
  `{:error, target, reason}`.

  ## Options
    * `:method` - `:http` (default) or `:icmp`
    * `:count` - Number of probes to send (default: `5`)
    * `:timeout` - Timeout in milliseconds (default: `5000`)
  """
  @spec ping(String.t(), keyword()) :: ping_result()
  def ping(target, opts \\ []) when is_binary(target) do
    method = Keyword.get(opts, :method, :http)
    count = Keyword.get(opts, :count, @default_count)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case method do
      :http -> http_ping(target, count, timeout)
      :icmp -> icmp_ping(target, count, timeout)
      other -> {:error, target, {:invalid_method, other}}
    end
  end

  # --- HTTP Latency Probe (/speedtest/latency.txt) ---

  defp http_ping(target, count, timeout) do
    url = build_latency_url(target)
    headers = [{"User-Agent", @user_agent}]
    http_opts = [recv_timeout: timeout, connect_timeout: timeout, follow_redirect: true]

    samples =
      for _ <- 1..count, reduce: [] do
        acc ->
          case measure_http_once(url, headers, http_opts) do
            {:ok, ms} -> [ms | acc]
            {:error, _} -> acc
          end
      end

    case samples do
      [] ->
        {:error, target, :unreachable}

      valid ->
        avg_ms = Float.round(Enum.sum(valid) / length(valid), 3)
        {:ok, target, avg_ms}
    end
  end

  defp measure_http_once(url, headers, opts) do
    {elapsed_us, resp} = :timer.tc(fn -> HTTP.client().get(url, headers, opts) end)

    case resp do
      {:ok, %{status_code: 200, body: body}} ->
        if String.trim(body) == "test=test" do
          {:ok, elapsed_us / 1_000}
        else
          {:error, :unexpected_body}
        end

      {:ok, %{status_code: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_latency_url(target) do
    cond do
      String.ends_with?(target, "/upload.php") ->
        String.replace_suffix(target, "/upload.php", "/latency.txt")

      String.starts_with?(target, ["http://", "https://"]) ->
        String.trim_trailing(target, "/") <> "/speedtest/latency.txt"

      true ->
        "http://#{target}/speedtest/latency.txt"
    end
  end
  # --- ICMP System Ping ---

  defp icmp_ping(target, count, timeout_ms) do
    host = strip_port_and_scheme(target)
    timeout_sec = max(div(timeout_ms, 1_000), 1)
    args = build_icmp_args(host, count, timeout_sec)

    with {output, 0} <- System.cmd("ping", args, stderr_to_stdout: true),
         {:ok, avg_ms} <- parse_average_rtt(output) do
      {:ok, target, avg_ms}
    else
      {:error, reason} -> {:error, target, reason}
      {output, exit_code} -> {:error, target, {:exit_code, exit_code, String.trim(output)}}
    end
  rescue
    e in ErlangError -> {:error, target, e.original}
  end

  defp strip_port_and_scheme(target) do
    target
    |> String.replace(~r{^https?://}, "")
    |> String.split("/", parts: 2)
    |> hd()
    |> Decoder.url()
  end

  defp build_icmp_args(host, count, timeout_sec) do
    case :os.type() do
      {:unix, :darwin} ->
        ["-c", to_string(count), "-t", to_string(timeout_sec), host]

      _ ->
        # Works on both iputils-ping (Debian/Ubuntu) and BusyBox ping (Alpine)
        ["-c", to_string(count), "-w", to_string(timeout_sec), host]
    end
  end

  defp parse_average_rtt(output) do
    regex = ~r/(?:rtt|round-trip)\s+min\/avg\/max(?:\/(?:mdev|stddev))?\s+=\s+[\d.]+\/([\d.]+)\//

    case Regex.run(regex, output) do
      [_, avg_str] ->
        case Float.parse(avg_str) do
          {avg, _} -> {:ok, avg}
          :error -> {:error, :invalid_float}
        end

      nil ->
        {:error, :unparseable_output}
    end
  end
end
