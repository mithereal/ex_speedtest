defmodule Speedtest.Result do
  import Speedtest.Decoder

  alias Speedtest.Result

  @default_key "297aae72"

  @moduledoc """
  A speedtest result.
  """

  defstruct download: nil,
            upload: nil,
            ping: nil,
            server: nil,
            client: nil,
            timestamp: nil,
            bytes_received: 0,
            bytes_sent: 0,
            share: nil

  @doc """
  Create a result from a speedtest
  """
  def create(speedtest, {upload_reply, download_reply}) do
    upload_times =
      Enum.map(upload_reply, fn x ->
        x.elapsed_time
      end)

    upload_sizes =
      Enum.map(upload_reply, fn x ->
        to_integer(x.bytes)
      end)

    upload_total_time_in_sec = Enum.sum(upload_times)

    upload_size_total_bytes = Enum.sum(upload_sizes)
    upload_size_total_mb = upload_size_total_bytes / 125_000

    upload = upload_size_total_mb / upload_total_time_in_sec

    upload_avg_sec = upload_total_time_in_sec / Enum.count(upload_reply)
    upload_avg_sec = upload_size_total_bytes / upload_avg_sec

    download_times =
      Enum.map(download_reply, fn x ->
        x.elapsed_time
      end)

    download_sizes =
      Enum.map(download_reply, fn x ->
        to_integer(x.bytes)
      end)

    download_time_in_sec = Enum.sum(download_times)

    download_size_total_bytes = Enum.sum(download_sizes)
    download_size_total_mb = download_size_total_bytes / 125_000

    download = download_size_total_mb / download_time_in_sec

    download_avg_sec = download_time_in_sec / Enum.count(download_reply)
    download_avg_sec = download_size_total_bytes / download_avg_sec

    client = %{speedtest.config.client | ispdlavg: trunc(Float.round(download_avg_sec))}
    client = %{client | ispulavg: trunc(Float.round(upload_avg_sec))}

    result = %Result{
      download: Float.round(download, 2),
      upload: Float.round(upload, 2),
      ping: speedtest.selected_server.ping,
      server: speedtest.selected_server,
      client: client,
      timestamp: DateTime.utc_now(),
      bytes_received: download_size_total_bytes,
      bytes_sent: upload_size_total_bytes,
      share: nil
    }

    reply = %{speedtest | result: result}

    {:ok, reply}
  end

  @doc """
  Share the results with speedtest.net
  """
  def share(%Result{} = result) do
    config_key = Application.get_env(:speedtest, :key)

    key =
      case config_key do
        nil ->
          @default_key

        _ ->
          config_key
      end

    {_, _, ping} = result.ping

    hash =
      :crypto.hash(
        :md5,
        to_string(ping) <>
          "-" <> to_string(result.upload) <> "-" <> to_string(result.download) <> "-" <> key
      )
      |> Base.encode16()

    download = round(result.download / 1000.0)
    ping = round(ping)
    upload = round(result.upload / 1000.0)

    api_data = [
      "recommendedserverid=" <> to_string(result.server.id),
      "ping=" <> to_string(ping),
      "screenresolution=",
      "promo=",
      "download=" <> to_string(download),
      "screendpi=",
      "upload=" <> to_string(upload),
      "testmethod=http",
      "hash=" <> hash,
      "touchscreen=none",
      "startmode=pingselect",
      "accuracy=1",
      "bytesreceived=" <> to_string(result.bytes_received),
      "bytessent=" <> to_string(result.bytes_sent),
      "serverid=" <> to_string(result.server.id)
    ]

    url = "https://www.speedtest.net/api/api.php"
    headers = [{"Referer", "http://c.speedtest.net/flash/speedtest.swf"}]
    body = Enum.join(api_data, "&")
    {_, response} = HTTPoison.post(url, body, headers)

    res = Regex.run(~r{resultid=(.)}, response.body)

    image = List.last(res)

    share = "http://www.speedtest.net/result/" <> image <> ".png"

    %{result | share: share}
  end
end
