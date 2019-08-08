defmodule Speedtest.Decoder do
  import SweetXml

  @download_sizes [350, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
  @upload_sizes [32768, 65536, 131_072, 262_144, 524_288, 1_048_576, 7_340_032]

  def url(data) do
    url = String.split(data, ":")
    List.first(url)
  end

  def client(data) do
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

    %{
      ip: to_string(result.ip),
      lat: to_float(result.lat),
      lon: to_float(result.lon),
      isp: to_string(result.isp),
      country: to_string(result.country),
      isprating: to_string(result.isprating),
      rating: to_string(result.rating),
      ispdlavg: to_string(result.ispdlavg),
      ispulavg: to_string(result.ispulavg)
    }
  end

  def server(data) do
    results =
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
Enum.map(results, fn(result) -> 
  %{
    url: to_string(result.url),
    lat: to_float(result.lat),
    lon: to_float(result.lon),
    name: to_string(result.name),
    country: to_string(result.country),
    cc: to_string(result.cc),
    sponsor: to_string(result.sponsor),
    id: to_string(result.id),
    host: to_string(result.host)
  }
end)
    
  end

  def server_config(data) do
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

    %{
      threadcount: to_integer(result.threadcount),
      notonmap: result.notonmap,
      forcepingid: result.forcepingid,
      preferredserverid: result.preferredserverid,
      ignoreids: result.ignoreids
    }
  end

  def config(data) do
    server_config = server_config(data)

    download = download(data)

    upload = upload(data)

    client = client(data)

    head = upload.ratio - 1

    tail = Enum.count(@upload_sizes) - 1

    upload_sizes = Enum.slice(@upload_sizes, head..tail)

    sizes = %{upload: upload_sizes, download: @download_sizes}

    size_count = Enum.count(sizes.upload)

    upload_count = upload.maxchunkcount / size_count

    counts = %{upload: upload_count, download: Float.round(download.threads)}

    threads = %{upload: upload.threads, download: server_config.threadcount * 2}

    length = %{upload: upload.testlength, download: download.testlength}

    reply = %{
      client: client,
      ignore_servers: server_config.ignoreids,
      sizes: sizes,
      counts: counts,
      threads: threads,
      length: length,
      upload_max: upload.maxchunkcount
    }

    reply
  end


  def to_integer(data) do
    data = to_string(data)

    String.to_integer(data)
  end

  def to_float(data) do
    data = to_string(data)

    String.to_float(data)
  end

  def license(data) do
    result =
      data.body
      |> xpath(~x"//licensekey/text()")

    to_string(result)
  end

  def odometer(data) do
    result =
      data.body
      |> xpath(
        ~x"//odometer",
        start: ~x"./@start",
        rate: ~x"./@rate"
      )

    %{start: to_integer(result.start), rate: to_integer(result.rate)}
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

    %{
      testlength: to_integer(result.testlength),
      initialtest: to_string(result.initialtest),
      mintestsize: to_string(result.mintestsize),
      threads: to_integer(result.threadsperurl)
    }
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

    %{
      ratio: to_integer(result.ratio),
      maxchunksize: to_string(result.maxchunksize),
      threads: to_integer(result.threads),
      testlength: to_integer(result.testlength),
      initialtest: to_integer(result.initialtest),
      mintestsize: to_string(result.mintestsize),
      maxchunkcount: to_integer(result.maxchunkcount)
    }
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

    %{
      testlength: to_integer(result.testlength),
      waittime: to_integer(result.waittime),
      timeout: to_integer(result.timeout)
    }
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

    %{
      testlength: to_integer(data.testlength),
      initialthreads: to_integer(result.initialthreads),
      minthreads: to_integer(result.minthreads),
      maxthreads: to_integer(result.maxthreads),
      threadratio: to_string(data.threadratio),
      maxsamplesize: to_integer(data.maxsamplesize),
      minsamplesize: to_integer(data.minsamplesize),
      startsamplesize: to_integer(data.startsamplesize),
      startbuffersize: to_integer(data.startbuffersize),
      bufferlength: to_integer(data.bufferlength),
      packetlength: to_integer(data.packetlength),
      readbuffer: to_integer(data.readbuffer)
    }
  end

  def socket_upload(data) do
    result =
      data.body
      |> xpath(
        ~x"//socket-upload",
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
        disabled: ~x"./@disabled"
      )

    disabled? =
      case result.disabled == "true" do
        true -> true
        false -> false
      end

    %{
      testlength: to_integer(data.testlength),
      initialthreads: to_string(result.initialthreads),
      minthreads: to_string(result.minthreads),
      maxthreads: to_integer(result.maxthreads),
      threadratio: to_string(data.threadratio),
      maxsamplesize: to_integer(data.maxsamplesize),
      minsamplesize: to_integer(data.minsamplesize),
      startsamplesize: to_integer(data.startsamplesize),
      startbuffersize: to_integer(data.startbuffersize),
      bufferlength: to_integer(data.bufferlength),
      packetlength: to_integer(data.packetlength),
      disabled: disabled?
    }
  end

  def socket_latency(data) do
    result =
      data.body
      |> xpath(
        ~x"//socket-latency",
        testlength: ~x"./@testlength",
        waittime: ~x"./@waittime",
        timeout: ~x"./@timeout"
      )

    %{
      testlength: to_integer(result.testlength),
      waittime: to_integer(result.waittime),
      timeout: to_integer(result.timeout)
    }
  end
end
