defmodule Speedtest.Decoder do
  @moduledoc """
  Decodes JSON configuration and server list responses from the Speedtest API.
  """

  @download_sizes [350, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
  @upload_sizes [32_768, 65_536, 131_072, 262_144, 524_288, 1_048_576, 7_340_032]

  @doc """
  Extracts the host/scheme prefix before the first colon in a URL string.
  """
  @spec url(String.t()) :: String.t()
  def url(data) when is_binary(data) do
    data |> String.split(":", parts: 2) |> hd()
  end

  @doc """
  Decodes client metadata from an HTTP response struct or JSON body.
  """
  @spec client(%{body: iodata()} | iodata()) :: map()
  def client(data) do
    json = decode_json(data)
    c = json["client"] || %{}
    loc = json["location"] || %{}

    %{
      ip: to_string(json["ipAddress"] || c["ip"] || ""),
      lat: parse_float(loc["latitude"] || c["lat"]),
      lon: parse_float(loc["longitude"] || c["lon"]),
      isp: to_string(json["ispName"] || c["isp"] || ""),
      country: to_string(loc["countryCode"] || c["country"] || ""),
      isprating: to_string(c["isprating"] || ""),
      rating: to_string(c["rating"] || ""),
      ispdlavg: to_string(c["ispdlavg"] || "0"),
      ispulavg: to_string(c["ispulavg"] || "0")
    }
  end

  @doc """
  Decodes all server entries from either `/api/js/servers` (a JSON list)
  or `/api/js/config-sdk` (which embeds `"servers"` inside the root object).
  """
  @spec server(%{body: iodata()} | iodata()) :: [map()]
  def server(data) do
    servers =
      case decode_json(data) do
        list when is_list(list) -> list
        %{"servers" => list} when is_list(list) -> list
        _ -> []
      end

    Enum.map(servers, fn s ->
      %{
        url: to_string(s["url"] || ""),
        lat: parse_float(s["lat"]),
        lon: parse_float(s["lon"]),
        name: to_string(s["name"] || ""),
        country: to_string(s["country"] || ""),
        cc: to_string(s["cc"] || ""),
        sponsor: to_string(s["sponsor"] || ""),
        id: to_string(s["id"] || ""),
        host: to_string(s["host"] || "")
      }
    end)
  end

  @doc """
  Decodes server configuration fields.
  """
  @spec server_config(%{body: iodata()} | iodata()) :: map()
  def server_config(data) do
    json = decode_json(data)
    cfg = json["server-config"] || json["serverConfig"] || %{}

    ignore_ids =
      case cfg["ignoreids"] || cfg["ignoreIds"] || json["ignoreIds"] do
        list when is_list(list) -> Enum.join(list, ",")
        str when is_binary(str) -> str
        _ -> ""
      end

    %{
      threadcount: parse_int(cfg["threadcount"] || cfg["threadCount"], 4),
      notonmap: to_string(cfg["notonmap"] || ""),
      forcepingid: to_string(cfg["forcepingid"] || ""),
      preferredserverid: to_string(cfg["preferredserverid"] || ""),
      ignoreids: ignore_ids
    }
  end

  @doc """
  Builds the combined test configuration map from the JSON config response.
  """
  @spec config(%{body: iodata()} | iodata()) :: map()
  def config(data) do
    json = decode_json(data)
    srv_cfg = server_config(json)
    dl = download(json)
    ul = upload(json)
    cl = client(json)

    upload_sizes = Enum.slice(@upload_sizes, max(ul.ratio - 1, 0)..-1//1)
    size_count = max(length(upload_sizes), 1)
    upload_count = round(ul.maxchunkcount / size_count)

    %{
      client: cl,
      ignore_servers: srv_cfg.ignoreids,
      sizes: %{upload: upload_sizes, download: @download_sizes},
      counts: %{upload: upload_count, download: dl.threads},
      threads: %{upload: ul.threads, download: srv_cfg.threadcount * 2},
      length: %{upload: ul.testlength, download: dl.testlength},
      upload_max: upload_count * size_count
    }
  end

  @doc """
  Decodes `licensekey` text.
  """
  @spec license(%{body: iodata()} | iodata()) :: String.t()
  def license(data) do
    json = decode_json(data)
    (json["licensekey"] || json["licenseKey"] || "") |> to_string()
  end

  @doc """
  Decodes `odometer` fields.
  """
  @spec odometer(%{body: iodata()} | iodata()) :: map()
  def odometer(data) do
    odo = decode_json(data)["odometer"] || %{}

    %{
      start: parse_int(odo["start"], 0),
      rate: parse_int(odo["rate"], 0)
    }
  end

  @doc """
  Decodes download configuration fields.
  """
  @spec download(%{body: iodata()} | iodata()) :: map()
  def download(data) do
    json = decode_json(data)
    dl = json["download"] || %{}

    %{
      testlength: parse_int(dl["testlength"] || dl["testLength"], 10),
      initialtest: to_string(dl["initialtest"] || "250K"),
      mintestsize: to_string(dl["mintestsize"] || "250K"),
      threads: parse_int(dl["threadsperurl"] || dl["threadsPerUrl"], 4)
    }
  end

  @doc """
  Decodes upload configuration fields.
  """
  @spec upload(%{body: iodata()} | iodata()) :: map()
  def upload(data) do
    json = decode_json(data)
    ul = json["upload"] || %{}

    %{
      testlength: parse_int(ul["testlength"] || ul["testLength"], 10),
      ratio: parse_int(ul["ratio"], 1),
      initialtest: parse_int(ul["initialtest"], 0),
      mintestsize: to_string(ul["mintestsize"] || "32K"),
      threads: parse_int(ul["threads"], 2),
      maxchunksize: to_string(ul["maxchunksize"] || "512K"),
      maxchunkcount: parse_int(ul["maxchunkcount"] || ul["maxChunkCount"], 50)
    }
  end

  @doc """
  Decodes latency configuration fields.
  """
  @spec latency(%{body: iodata()} | iodata()) :: map()
  def latency(data) do
    json = decode_json(data)
    lat = json["latency"] || %{}

    %{
      testlength: parse_int(lat["testlength"], 10),
      waittime: parse_int(lat["waittime"], 50),
      timeout: parse_int(lat["timeout"], 20)
    }
  end

  @doc """
  Decodes `socket-download` fields.
  """
  @spec socket_download(%{body: iodata()} | iodata()) :: map()
  def socket_download(data) do
    json = decode_json(data)
    sd = json["socket-download"] || json["socketDownload"] || %{}

    %{
      testlength: parse_int(sd["testlength"] || sd["testLength"], 15),
      initialthreads: parse_int(sd["initialthreads"] || sd["initialThreads"], 4),
      minthreads: parse_int(sd["minthreads"] || sd["minThreads"], 4),
      maxthreads: parse_int(sd["maxthreads"] || sd["maxThreads"], 32),
      threadratio: to_string(sd["threadratio"] || sd["threadRatio"] || "750K"),
      maxsamplesize: parse_int(sd["maxsamplesize"] || sd["maxSampleSize"], 5_000_000),
      minsamplesize: parse_int(sd["minsamplesize"] || sd["minSampleSize"], 32_000),
      startsamplesize: parse_int(sd["startsamplesize"] || sd["startSampleSize"], 1_000_000),
      startbuffersize: parse_int(sd["startbuffersize"] || sd["startBufferSize"], 1),
      bufferlength: parse_int(sd["bufferlength"] || sd["bufferLength"], 5_000),
      packetlength: parse_int(sd["packetlength"] || sd["packetLength"], 1_000),
      readbuffer: parse_int(sd["readbuffer"] || sd["readBuffer"], 65_536)
    }
  end

  @doc """
  Decodes `socket-upload` fields.
  """
  @spec socket_upload(%{body: iodata()} | iodata()) :: map()
  def socket_upload(data) do
    json = decode_json(data)
    su = json["socket-upload"] || json["socketUpload"] || %{}
    disabled = su["disabled"] in [true, "true"]

    %{
      testlength: parse_int(su["testlength"] || su["testLength"], 15),
      initialthreads: to_string(su["initialthreads"] || su["initialThreads"] || "dyn:tcpulthreads"),
      minthreads: to_string(su["minthreads"] || su["minThreads"] || "dyn:tcpulthreads"),
      maxthreads: parse_int(su["maxthreads"] || su["maxThreads"], 32),
      threadratio: to_string(su["threadratio"] || su["threadRatio"] || "750K"),
      maxsamplesize: parse_int(su["maxsamplesize"] || su["maxSampleSize"], 1_000_000),
      minsamplesize: parse_int(su["minsamplesize"] || su["minSampleSize"], 32_000),
      startsamplesize: parse_int(su["startsamplesize"] || su["startSampleSize"], 100_000),
      startbuffersize: parse_int(su["startbuffersize"] || su["startBufferSize"], 2),
      bufferlength: parse_int(su["bufferlength"] || su["bufferLength"], 1_000),
      packetlength: parse_int(su["packetlength"] || su["packetLength"], 1_000),
      disabled: disabled
    }
  end

  @doc """
  Decodes `socket-latency` fields.
  """
  @spec socket_latency(%{body: iodata()} | iodata()) :: map()
  def socket_latency(data) do
    json = decode_json(data)
    sl = json["socket-latency"] || json["socketLatency"] || %{}

    %{
      testlength: parse_int(sl["testlength"] || sl["testLength"], 10),
      waittime: parse_int(sl["waittime"] || sl["waitTime"], 50),
      timeout: parse_int(sl["timeout"], 20)
    }
  end

  # Keeps backwards compatibility if any external caller relied on these helpers
  @doc false
  def to_integer(data), do: parse_int(data, 0)

  @doc false
  def to_float(data), do: parse_float(data)

  # --- Private Helpers ---

  defp decode_json(%{} = map) when not is_struct(map) and not is_map_key(map, :body), do: map
  defp decode_json(%{body: body}), do: decode_json(body)
  defp decode_json(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_json(body), do: body |> IO.iodata_to_binary() |> Jason.decode!()

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
