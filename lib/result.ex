defmodule Speedtest.Result do

    import Speedtest.Decoder

  defstruct download: nil,
            upload: nil

  def create( {upload_reply, download_reply}) do

    upload_times = Enum.map(upload_reply, fn(x) ->
       x.elapsed_time
    end)

    download_times = Enum.map(download_reply, fn(x) ->
        x.elapsed_time
    end)

    download_sizes = Enum.map(download_reply, fn(x) ->
        to_integer(x.bytes)
    end)


    upload_times = Enum.sum(upload_times)

    upload_sizes = Enum.map(upload_reply, fn(x) ->
        to_integer(x.bytes)
    end)


    upload_avg = upload_times / Enum.count(upload_reply)

    upload_size_total = Enum.sum(upload_sizes)

    download_time = Enum.sum(download_times)

    download_avg = download_time / Enum.count(download_reply)

    download_size_total = Enum.sum(download_sizes)

    data = %{avg_upload_microseconds: upload_avg, avg_download_microseconds: download_avg, upload_total: upload_size_total, download_total: download_size_total, raw: %{upload: upload_reply, download: download_reply} }

    {:ok, data}
  end
end
