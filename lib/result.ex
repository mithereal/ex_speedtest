defmodule Speedtest.Result do
  import Speedtest.Decoder

  alias Speedtest.Result

  @key "297aae72"

  defstruct download: nil,
            upload: nil,
            ping: nil,
            server: nil,
            client: nil,
            timestamp: nil,
            bytes_recieved: 0,
            bytes_sent: 0,
            share: nil

  def create({upload_reply, download_reply}) do
    upload_times =
      Enum.map(upload_reply, fn x ->
        x.elapsed_time
      end)

    download_times =
      Enum.map(download_reply, fn x ->
        x.elapsed_time
      end)

    download_sizes =
      Enum.map(download_reply, fn x ->
        to_integer(x.bytes)
      end)

    upload_times = Enum.sum(upload_times)

    upload_sizes =
      Enum.map(upload_reply, fn x ->
        to_integer(x.bytes)
      end)

    upload_avg = upload_times / Enum.count(upload_reply)

    upload_size_total = Enum.sum(upload_sizes)

    download_time = Enum.sum(download_times)

    download_avg = download_time / Enum.count(download_reply)

    download_size_total = Enum.sum(download_sizes)

    data = %{
      avg_upload_microseconds: upload_avg,
      avg_download_microseconds: download_avg,
      upload_total: upload_size_total,
      download_total: download_size_total,
      raw: %{upload: upload_reply, download: download_reply}
    }

    # result = %Result{
    #   download: nil,
    #   upload: nil,
    #   ping: nil,
    #   server: nil,
    #   client: nil,
    #   timestamp: nil,
    #   bytes_recieved: 0,
    #   bytes_sent: 0,
    #   share: share
    # }

    {:ok, data}
  end

  def share(%Result{} = result) do
    hash =
      :crypto.hash(
        :md5,
        to_string(result.ping) <>
          "-" <> to_string(result.upload) <> "-" <> to_string(result.download) <> "-" <> @key
      )
      |> Base.encode16()

    api_data = [
      "recommendedserverid=" <> to_string(result.server.id),
      "ping=" <> to_string(result.ping),
      "screenresolution=",
      "promo=",
      "download=" <> to_string(result.download),
      "screendpi=",
      "upload=" <> to_string(result.upload),
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

    image = "response.image"

    share = "http://www.speedtest.net/result/" <> image <> "/png"

    %{result | share: share}
  end
end
