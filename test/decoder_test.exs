defmodule Speedtest.DecoderTest do
  use ExUnit.Case, async: true

  alias Speedtest.Decoder

  @config_json """
  {
    "client": {
      "ip": "174.127.193.8",
      "lat": "48.2011",
      "lon": "-122.378",
      "isp": "Wave Broadband",
      "isprating": "3.7",
      "rating": "0",
      "ispdlavg": "0",
      "ispulavg": "0",
      "loggedin": "0",
      "country": "US"
    },
    "server-config": {
      "threadcount": 4,
      "ignoreids": "683,1525,1716",
      "notonmap": "10588,16148",
      "forcepingid": "",
      "preferredserverid": ""
    },
    "licensekey": "f7a45ced624d3a70-1df5b7cd427370f7-b91ee21d6cb22d7b",
    "customer": "speedtest",
    "odometer": {
      "start": 19046241464,
      "rate": 10
    },
    "download": {
      "testlength": 10,
      "initialtest": "250K",
      "mintestsize": "250K",
      "threadsperurl": 4
    },
    "upload": {
      "testlength": 10,
      "ratio": 5,
      "initialtest": 0,
      "mintestsize": "32K",
      "threads": 2,
      "maxchunksize": "512K",
      "maxchunkcount": 50,
      "threadsperurl": 4
    },
    "latency": {
      "testlength": 10,
      "waittime": 50,
      "timeout": 20
    },
    "socket-download": {
      "testlength": 15,
      "initialthreads": 4,
      "minthreads": 4,
      "maxthreads": 32,
      "threadratio": "750K",
      "maxsamplesize": 5000000,
      "minsamplesize": 32000,
      "startsamplesize": 1000000,
      "startbuffersize": 1,
      "bufferlength": 5000,
      "packetlength": 1000,
      "readbuffer": 65536
    },
    "socket-upload": {
      "testlength": 15,
      "initialthreads": "dyn:tcpulthreads",
      "minthreads": "dyn:tcpulthreads",
      "maxthreads": 32,
      "threadratio": "750K",
      "maxsamplesize": 1000000,
      "minsamplesize": 32000,
      "startsamplesize": 100000,
      "startbuffersize": 2,
      "bufferlength": 1000,
      "packetlength": 1000,
      "disabled": false
    },
    "socket-latency": {
      "testlength": 10,
      "waittime": 50,
      "timeout": 20
    }
  }
  """

  @servers_json """
  [
    {
      "url": "http://guam.net",
      "lat": "34.0549",
      "lon": "-118.2426",
      "name": "Los Angeles, CA",
      "country": "United States",
      "cc": "US",
      "sponsor": "Docomo Pacific",
      "id": "72957",
      "host": "dpac-la.guam.net:8080"
    },
    {
      "url": "http://geolinks.com",
      "lat": "34.0549",
      "lon": "-118.2426",
      "name": "Los Angeles, CA",
      "country": "United States",
      "cc": "US",
      "sponsor": "GeoLinks",
      "id": "60433",
      "host": "://geolinks.com"
    }
  ]
  """

  test "url/1 strips port from host string" do
    assert Decoder.url("dpac-la.guam.net:8080") == "dpac-la.guam.net"
    assert Decoder.url("example.com") == "example.com"
  end

  test "client/1 decodes client metadata from response map or raw JSON" do
    expected = %{
      ip: "174.127.193.8",
      lat: 48.2011,
      lon: -122.378,
      isp: "Wave Broadband",
      country: "US",
      isprating: "3.7",
      rating: "0",
      ispdlavg: "0",
      ispulavg: "0"
    }

    assert Decoder.client(%{body: @config_json}) == expected
    assert Decoder.client(@config_json) == expected
  end

  test "server/1 decodes server list" do
    servers = Decoder.server(%{body: @servers_json})
    assert length(servers) == 2

    assert hd(servers) == %{
             url: "http://guam.net",
             lat: 34.0549,
             lon: -118.2426,
             name: "Los Angeles, CA",
             country: "United States",
             cc: "US",
             sponsor: "Docomo Pacific",
             id: "72957",
             host: "dpac-la.guam.net:8080"
           }
  end

  test "config/1 builds combined sizes, counts, threads, and lengths" do
    cfg = Decoder.config(%{body: @config_json})

    assert cfg.ignore_servers == "683,1525,1716"
    assert cfg.sizes.upload == [524_288, 1_048_576, 7_340_032]
    assert cfg.counts == %{upload: 17, download: 4}
    assert cfg.threads == %{upload: 2, download: 8}
    assert cfg.length == %{upload: 10, download: 10}
    assert cfg.upload_max == 51
  end

  test "license/1 and odometer/1 decode license key and odometer fields" do
    assert Decoder.license(@config_json) ==
             "f7a45ced624d3a70-1df5b7cd427370f7-b91ee21d6cb22d7b"

    assert Decoder.odometer(@config_json) == %{start: 19_046_241_464, rate: 10}
  end

  test "socket_download/1, socket_upload/1, and socket_latency/1 decode socket settings" do
    sd = Decoder.socket_download(@config_json)
    assert sd.testlength == 15
    assert sd.maxthreads == 32
    assert sd.threadratio == "750K"
    assert sd.readbuffer == 65_536

    su = Decoder.socket_upload(@config_json)
    assert su.testlength == 15
    assert su.initialthreads == "dyn:tcpulthreads"
    assert su.disabled == false

    sl = Decoder.socket_latency(@config_json)
    assert sl == %{testlength: 10, waittime: 50, timeout: 20}
  end
end
