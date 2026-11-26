# Speedtest

[![Hex.pm](https://shields.io)](https://hex.pm/packages/speedtest)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/speedtest/)
[![Downloads](https://img.shields.io/hexpm/dt/speedtest.svg)](https://hex.pm/packages/speedtest)
[![License](https://img.shields.io/hexpm/l/speedtest.svg)](https://github.com)
[![Last Updated](https://img.shields.io/github/last-commit/mithereal/ex_speedtest.svg)](https://github.com/mithereal/ex_speedtest/commits/master)

**Elixir client for testing internet bandwidth using Speedtest.net.**

## Installation

Add `speedtest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:speedtest, "~> 1.2.0"}
  ]
end
```

## Usage

Run a full speedtest (config lookup, server selection, ping, download, and upload):

```elixir
{:ok, speedtest} = Speedtest.run()

speedtest.result.download #=> 142.85 (Mbit/s)
speedtest.result.upload   #=> 38.12  (Mbit/s)
speedtest.result.ping     #=> {:ok, "dpac-la.guam.net:8080", 14.2}
```

### Ping Options (`:http` vs `:icmp`)

By default, latency is measured via Ookla's HTTP `/speedtest/latency.txt` endpoint (`method: :http`), which works in containerized and cloud environments without raw ICMP socket permissions. You can also use the system `ping` command (`method: :icmp`):

```elixir
# Default HTTP latency probe
Speedtest.run(method: :http, count: 5, timeout: 5_000)

# System ICMP ping
Speedtest.run(method: :icmp)

# Ping a single host directly
Speedtest.ping("dpac-la.guam.net:8080", method: :http)
```

### Sharing Results

Submit a completed `%Speedtest.Result{}` to Speedtest.net to generate a shareable PNG summary image:

```elixir
{:ok, speedtest} = Speedtest.run()
{:ok, shared_result} = Speedtest.Result.share(speedtest.result)

shared_result.share
#=> "https://speedtest.net"
```

## Configuration (Optional)

```elixir
config :speedtest,
  key: "297aae72",
  threads: nil,
  include: nil,
  exclude: nil
```

* `:key` — API key used to sign Speedtest.net result submissions.
* `:threads` — Override the server-configured concurrency for download/upload transfers.
* `:include` — List of server IDs to whitelist (e.g., `["72957", "60433"]`).
* `:exclude` — List of server IDs to blacklist (automatically merged with Speedtest's `ignoreids`).

## Documentation

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and available on [HexDocs](https://hexdocs.pm/speedtest).
