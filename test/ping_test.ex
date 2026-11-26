defmodule Speedtest.PingTest do
  use ExUnit.Case, async: true

  import Mox

  alias Speedtest.{HTTPMock, Ping}

  setup :verify_on_exit!

  describe "ping/2 (:http mode)" do
    test "returns {:ok, target, avg_ms} when latency.txt returns test=test" do
      expect(HTTPMock, :get, 3, fn url, _headers, _opts ->
        assert url == "http://guam.net"
        {:ok, %{status_code: 200, headers: [], body: "test=test\n"}}
      end)

      assert {:ok, "dpac-la.guam.net:8080", avg_ms} =
               Ping.ping("dpac-la.guam.net:8080", count: 3)

      assert is_float(avg_ms)
      assert avg_ms >= 0.0
    end

    test "replaces /upload.php suffix with /latency.txt when given a full server URL" do
      expect(HTTPMock, :get, 1, fn url, _headers, _opts ->
        assert url == "http://guam.net"
        {:ok, %{status_code: 200, headers: [], body: "test=test"}}
      end)

      assert {:ok, _, _ms} =
               Ping.ping("http://guam.net", count: 1)
    end

    test "returns {:error, target, :unreachable} when all probes fail or return unexpected bodies" do
      expect(HTTPMock, :get, 2, fn _url, _headers, _opts ->
        {:ok, %{status_code: 503, headers: [], body: "Service Unavailable"}}
      end)

      assert {:error, "://example.com", :unreachable} =
               Ping.ping("://example.com", count: 2)
    end
  end
end
