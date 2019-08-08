defmodule Speedtest.Decoder do
  import SweetXml

  def url(data) do
    url = String.split(data, ":")
    List.first(url)
  end

  def ip(data) do
    result =
      data.body
      |> xpath(
        ~x"//client",
        ip: ~x"./@ip",
        lat: ~x"./@lat",
        lon: ~x"./@lon",
        isp: ~x"./@isp",
        country: ~x"./@country",
        isprating: ~x"./@isprating",
        rating: ~x"./@rating",
        ispdlavg: ~x"./@ispdlavg",
        ispulavg: ~x"./@ispulavg"
      )
  end

  def server(data) do
    result =
      data.body
      |> xpath(
        ~x"//servers/server"l,
        url: ~x"./@url",
        lat: ~x"./@lat",
        lon: ~x"./@lon",
        name: ~x"./@name",
        country: ~x"./@country",
        cc: ~x"./@cc",
        sponsor: ~x"./@sponsor",
        id: ~x"./@id",
        host: ~x"./@host"
      )
  end

  def settings(data) do
    result =
      data.body
      |> xpath(
        ~x"//server-config",
        threadcount: ~x"./@threadcount",
        notonmap: ~x"./@notonmap",
        forcepingid: ~x"./@forcepingid",
        preferredserverid: ~x"./@preferredserverid",
        ignoreids: ~x"./@ignoreids"
      )

    result
  end

  def license(data) do
    result =
      data.body
      |> xpath(~x"//licensekey/text()")

    result
  end

  def odometer(data) do
    result =
      data.body
      |> xpath(
        ~x"//odometer",
        start: ~x"./@start",
        rate: ~x"./@rate"
      )

    result
  end

  def download(data) do
    result =
      data.body
      |> xpath(
        ~x"//download",
        testlength: ~x"./@testlength",
        initialtest: ~x"./@initialtest",
        mintestsize: ~x"./@mintestsize",
        threadsperurl: ~x"./@threadsperurl"
      )

    result
  end

  def upload(data) do
    result =
      data.body
      |> xpath(
        ~x"//upload",
        testlength: ~x"./@testlength",
        ratio: ~x"./@ratio",
        initialtest: ~x"./@initialtest",
        mintestsize: ~x"./@mintestsize",
        threads: ~x"./@threads",
        maxchunksize: ~x"./@maxchunksize",
        maxchunkcount: ~x"./@maxchunkcount",
        threadsperurl: ~x"./@threadsperurl"
      )

    result
  end

  def latency(data) do
    result =
      data.body
      |> xpath(
        ~x"//latency",
        testlength: ~x"./@testlength",
        waittime: ~x"./@waittime",
        timeout: ~x"./@timeout"
      )

    result
  end

  def socket_download(data) do
    result =
      data.body
      |> xpath(
        ~x"//socket-download",
        testlength: ~x"./@testlength",
        initialthreads: ~x"./@initialthreads",
        minthreads: ~x"./@minthreads",
        maxthreads: ~x"./@maxthreads",
        threadratio: ~x"./@threadratio",
        maxsamplesize: ~x"./@maxsamplesize",
        minsamplesize: ~x"./@minsamplesize",
        startsamplesize: ~x"./@startsamplesize",
        startbuffersize: ~x"./@startbuffersize",
        bufferlength: ~x"./@bufferlength",
        packetlength: ~x"./@packetlength",
        readbuffer: ~x"./@readbuffer"
      )

    result
  end
end
