defmodule Speedtest.Result do
  defstruct download: nil,
            upload: nil

  def create( {upload_reply, download_reply}) do

    upload_times = Enum.map(upload_reply, fn(x) ->
        {time, _} = x
        time
    end)

    download_times = Enum.map(download_reply, fn(x) ->
        {time, _} = x
        time
    end)


    upload_time = Enum.sum(upload_times)

    upload_avg = upload_time / Enum.count(upload_reply)

    download_time = Enum.sum(download_times)

    download_avg = download_time / Enum.count(download_reply)

    data = %{avg_upload_microseconds: upload_avg, avg_download_microseconds: download_avg}

    {:ok, data}
  end
end
