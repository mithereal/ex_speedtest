defmodule Speedtest.Result do
  @moduledoc """
  Represents a completed Speedtest measurement and handles formatting and
  sharing results with Speedtest.net.
  """

  import Speedtest.Decoder, only: [to_integer: 1]

  alias Speedtest.HTTP

  @default_key "297aae72"
  @share_url "https://speedtest.net"
  @share_headers [
    {"Referer", "https://speedtest.net"},
    {"Content-Type", "application/x-www-form-urlencoded"}
  ]

  defstruct download: nil,
            upload: nil,
            ping: nil,
            server: nil,
            client: nil,
            timestamp: nil,
            bytes_received: 0,
            bytes_sent: 0,
            share: nil

  @type t :: %__MODULE__{
               download: float() | nil,
               upload: float() | nil,
               ping: tuple() | number() | nil,
               server: map() | nil,
               client: map() | nil,
               timestamp: DateTime.t() | nil,
               bytes_received: non_neg_integer(),
               bytes_sent: non_neg_integer(),
               share: String.t() | nil
             }

  @doc """
  Creates a `%Speedtest.Result{}` from upload and download transfer samples
  and attaches it to the given `speedtest` struct/map.
  """
  @spec create(map(), {list(map()), list(map())}) :: {:ok, map()}
  def create(speedtest, {upload_reply, download_reply}) do
    {ul_mbps, ul_bps, bytes_sent} = calculate_metrics(upload_reply)
    {dl_mbps, dl_bps, bytes_received} = calculate_metrics(download_reply)

    updated_client = %{
      speedtest.config.client
    | ispdlavg: round(dl_bps),
      ispulavg: round(ul_bps)
    }

    result = %__MODULE__{
      download: Float.round(dl_mbps, 2),
      upload: Float.round(ul_mbps, 2),
      ping: speedtest.selected_server.ping,
      server: speedtest.selected_server,
      client: updated_client,
      timestamp: DateTime.utc_now(),
      bytes_received: bytes_received,
      bytes_sent: bytes_sent,
      share: nil
    }

    {:ok, %{speedtest | result: result}}
  end

  @doc """
  Submits the result to Speedtest.net and populates the `:share` PNG URL.
  Returns `{:ok, updated_result}` or `{:error, reason}`.
  """
  @spec share(t()) :: {:ok, t()} | {:error, term()}
  def share(%__MODULE__{} = result) do
    ping_ms = extract_ping_ms(result.ping)
    download_kbps = round(result.download * 1000)
    upload_kbps = round(result.upload * 1000)
    rounded_ping = round(ping_ms)

    body = build_share_payload(result, rounded_ping, download_kbps, upload_kbps)

    with {:ok, %{status_code: 200, body: resp_body}} <-
           HTTP.client().post(@share_url, body, @share_headers, follow_redirect: true),
         {:ok, result_id} <- parse_result_id(resp_body) do
      {:ok, %{result | share: "https://speedtest.netresult/#{result_id}.png"}}
    else
      {:ok, %{status_code: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Private Helpers ---

  defp calculate_metrics([]), do: {0.0, 0.0, 0}

  defp calculate_metrics(samples) do
    {total_bytes, total_sec, count} =
      Enum.reduce(samples, {0, 0.0, 0}, fn sample, {bytes_acc, time_acc, count_acc} ->
        {
          bytes_acc + to_integer(sample.bytes),
          time_acc + sample.elapsed_time,
          count_acc + 1
        }
      end)

    if total_sec > 0 do
      mbps = total_bytes / 1_000_000 * 8 / total_sec
      avg_sec = total_sec / count
      bps = total_bytes / avg_sec
      {mbps, bps, total_bytes}
    else
      {0.0, 0.0, total_bytes}
    end
  end

  defp extract_ping_ms({:ok, _host, ms}), do: ms
  defp extract_ping_ms(ms) when is_number(ms), do: ms

  defp build_share_payload(result, ping, download, upload) do
    key = Application.get_env(:speedtest, :key, @default_key)
    hash = compute_hash(ping, upload, download, key)

    URI.encode_query(%{
      "recommendedserverid" => result.server.id,
      "ping" => ping,
      "screenresolution" => "",
      "promo" => "",
      "download" => download,
      "screendpi" => "",
      "upload" => upload,
      "testmethod" => "http",
      "hash" => hash,
      "touchscreen" => "none",
      "startmode" => "pingselect",
      "accuracy" => 1,
      "bytesreceived" => result.bytes_received,
      "bytessent" => result.bytes_sent,
      "serverid" => result.server.id
    })
  end

  defp compute_hash(ping, upload, download, key) do
    :crypto.hash(:md5, "#{ping}-#{upload}-#{download}-#{key}")
    |> Base.encode16(case: :lower)
  end

  defp parse_result_id(body) do
    case Regex.run(~r/resultid=(\d+)/, body) do
      [_, id] -> {:ok, id}
      nil -> {:error, {:invalid_response, body}}
    end
  end
end
