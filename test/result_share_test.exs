defmodule Speedtest.ResultShareTest do
  use ExUnit.Case, async: true

  import Mox

  alias Speedtest.{HTTPMock, Result}

  setup :verify_on_exit!

  test "share/1 posts encoded metrics and parses the multi-digit resultid URL" do
    result = %Result{
      download: 125.6,
      upload: 42.3,
      ping: {:ok, "dpac-la.guam.net:8080", 14.2},
      server: %{id: "72957"},
      bytes_received: 15_000_000,
      bytes_sent: 5_000_000
    }

    expect(HTTPMock, :post, fn url, body, headers, _opts ->
      assert url == "https://speedtest.net"
      assert {"Referer", "https://speedtest.net"} in headers
      assert {"Content-Type", "application/x-www-form-urlencoded"} in headers

      params = URI.decode_query(body)
      assert params["serverid"] == "72957"
      assert params["ping"] == "14"
      assert params["download"] == "125600"
      assert params["upload"] == "42300"
      assert params["bytesreceived"] == "15000000"
      assert params["bytessent"] == "5000000"
      assert String.length(params["hash"]) == 32

      {:ok, %{status_code: 200, headers: [], body: "resultid=9876543210&date=11-25-2026"}}
    end)

    assert {:ok, shared} = Result.share(result)
    assert shared.share == "https://speedtest.netresult/9876543210.png"
  end

  test "share/1 returns {:error, {:http_error, status, body}} on non-200 responses" do
    result = %Result{
      download: 50.0,
      upload: 10.0,
      ping: {:ok, "host", 20.0},
      server: %{id: "1"}
    }

    expect(HTTPMock, :post, fn _url, _body, _headers, _opts ->
      {:ok, %{status_code: 500, headers: [], body: "Internal Error"}}
    end)

    assert {:error, {:http_error, 500, "Internal Error"}} = Result.share(result)
  end
end

defmodule Speedtest.RunTest do
  use ExUnit.Case, async: true

  import Mox

  alias Speedtest.HTTPMock

  setup :verify_on_exit!

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
      "threadcount": 2,
      "ignoreids": "60433",
      "notonmap": "",
      "forcepingid": "",
      "preferredserverid": ""
    },
    "download": {
      "testlength": 10,
      "initialtest": "250K",
      "mintestsize": "250K",
      "threadsperurl": 2
    },
    "upload": {
      "testlength": 10,
      "ratio": 6,
      "initialtest": 0,
      "mintestsize": "32K",
      "threads": 2,
      "maxchunksize": "512K",
      "maxchunkcount": 4,
      "threadsperurl": 2
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

  test "run/1 executes full config, server filtering, ping, download, and upload flow" do
    # Note: Task.async_stream spawns child processes, so allow them to use HTTPMock
    Mox.set_mox_global()

    stub(HTTPMock, :get, fn url, _headers, _opts ->
      cond do
        String.contains?(url, "/api/js/config-sdk") ->
          {:ok, %{status_code: 200, headers: [], body: @config_json}}

        String.contains?(url, "/api/js/servers") ->
          {:ok, %{status_code: 200, headers: [], body: @servers_json}}

        String.ends_with?(url, "/speedtest/latency.txt") ->
          # Server 60433 was filtered out by ignoreids="60433", so only 72957 is pinged
          assert String.contains?(url, "dpac-la.guam.net:8080")
          {:ok, %{status_code: 200, headers: [], body: "test=test"}}

        String.contains?(url, "/speedtest/random") ->
          {:ok, %{status_code: 200, headers: [{"Content-Length", "1000000"}], body: ""}}
      end
    end)

    stub(HTTPMock, :post, fn url, payload, _headers, _opts ->
      assert url == "http://guam.net"
      assert byte_size(payload) > 0
      {:ok, %{status_code: 200, headers: [], body: "size=#{byte_size(payload)}"}}
    end)

    assert {:ok, st} = Speedtest.run(count: 1)
    assert st.selected_server.id == "72957"
    assert st.result.bytes_received == 10_000_000
    assert st.result.bytes_sent > 0
    assert st.result.download > 0.0
    assert st.result.upload > 0.0
  end
end
