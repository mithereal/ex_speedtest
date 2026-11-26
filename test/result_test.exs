defmodule Speedtest.ResultTest do
  use ExUnit.Case, async: true

  alias Speedtest.Result

  test "create/2 calculates download/upload speeds, byte totals, and client averages" do
    speedtest = %Speedtest{
      config: %{
        client: %{
          ip: "174.127.193.8",
          lat: 48.2011,
          lon: -122.378,
          isp: "Wave Broadband",
          ispdlavg: "0",
          ispulavg: "0"
        }
      },
      selected_server: %{
        id: "72957",
        sponsor: "Docomo Pacific",
        name: "Los Angeles, CA",
        ping: {:ok, "dpac-la.guam.net:8080", 18.42}
      }
    }

    # 2 samples of 1,000,000 bytes each in 0.5s total = 2 MB in 0.5s = 32.0 Mbit/s
    download_samples = [
      %{elapsed_time: 0.25, bytes: 1_000_000, url: "http://example.com"},
      %{elapsed_time: 0.25, bytes: 1_000_000, url: "http://example.com"}
    ]

    # 2 samples of 500,000 bytes each in 1.0s total = 1 MB in 1.0s = 8.0 Mbit/s
    upload_samples = [
      %{elapsed_time: 0.5, bytes: 500_000, url: "http://example.com"},
      %{elapsed_time: 0.5, bytes: 500_000, url: "http://example.com"}
    ]

    assert {:ok, updated} = Result.create(speedtest, {upload_samples, download_samples})
    assert updated.result.download == 32.0
    assert updated.result.upload == 8.0
    assert updated.result.bytes_received == 2_000_000
    assert updated.result.bytes_sent == 1_000_000
    assert updated.result.ping == {:ok, "dpac-la.guam.net:8080", 18.42}
    assert %DateTime{} = updated.result.timestamp

    # Average bytes per sample / average seconds per sample:
    # Download: 2,000,000 bytes / 0.25s avg = 8,000,000 bps
    assert updated.result.client.ispdlavg == 8_000_000
    # Upload: 1,000,000 bytes / 0.5s avg = 2,000,000 bps
    assert updated.result.client.ispulavg == 2_000_000
  end

  test "create/2 handles empty sample lists without dividing by zero" do
    speedtest = %Speedtest{
      config: %{client: %{ispdlavg: "0", ispulavg: "0"}},
      selected_server: %{id: "1", ping: {:ok, "host", 10.0}}
    }

    assert {:ok, updated} = Result.create(speedtest, {[], []})
    assert updated.result.download == 0.0
    assert updated.result.upload == 0.0
    assert updated.result.bytes_received == 0
    assert updated.result.bytes_sent == 0
  end
end

defmodule SpeedtestTest do
  use ExUnit.Case, async: true

  test "distance/1 computes rounded distance in meters from client coordinates" do
    speedtest = %Speedtest{
      config: %{client: %{lat: 48.2011, lon: -122.378}},
      servers: [
        %{id: "72957", name: "Los Angeles, CA", lat: 34.0549, lon: -118.2426},
        %{id: "30043", name: "Beloit, KS", lat: 39.4628, lon: -98.1094}
      ]
    }

    assert {:ok, updated} = Speedtest.distance(speedtest)
    [la, ks] = updated.servers

    # ~1,611 km to Los Angeles, ~2,175 km to Beloit, KS
    assert_in_delta la.distance, 1_611_000, 10_000
    assert_in_delta ks.distance, 2_175_000, 10_000
  end

  test "choose_closest_servers/2 sorts by distance ascending and limits count" do
    servers = [
      %{id: "3", distance: 500_000},
      %{id: "1", distance: 100_000},
      %{id: "2", distance: 250_000}
    ]

    assert [%{id: "1"}, %{id: "2"}] = Speedtest.choose_closest_servers(servers, 2)
  end

  test "choose_best_server/2 returns error when no servers are reachable" do
    assert {:error, :no_reachable_servers} = Speedtest.choose_best_server([])
  end

  test "ping/2 rejects unknown ping methods cleanly" do
    assert {:error, "example.com", {:invalid_method, :udp}} =
             Speedtest.ping("example.com", method: :udp)
  end
end
